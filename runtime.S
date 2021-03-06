#if defined(__WIN32__) || defined(__APPLE__)
# define cdecl(s) _##s
#else
# define cdecl(s) s
#endif

         .global cdecl(garlic_fncall)
         .global cdecl(gather_varargs)
         .global cdecl(garlic_call_function)
         .global cdecl(garlicval_to_int)

         .text

cdecl(garlic_fncall):
        # This function is called with the wrapped lambda, and the number of
        # arguments to the lambda as the arguments. A new frame is created
        # using the lambda's parent frame as the parent, and the function
        # pointer is retrieved and called.
        #
        # All the arguments to the lambda are stored in the stack right to
        # left (i.e. the right-most argument is pushed onto the stack first).
        # It is the callee's responsiblity to handle the arguments.
        #
        # Note that %rsi (number of arguments to the lambda) should be passed
        # as is, since it is needed for varargs.
        push    %rdi                    # save the lambda on the stack
        push    %rsi                    # save the number of arguments
        sub     $8, %rsp                # align the stack
        mov     8(%rdi), %rdi           # create a new frame using the lambda's
        call    cdecl(new_frame_with_parent) # stored frame as the parent
        mov     %rax, %rdi              # make room for the lambda
        add     $8, %rsp                # unalign the stack
        pop     %rsi                    # grab the number of arguments again
        pop     %rax                    #   and the lambda
        push    %rdi                    # save the new frame
        mov     16(%rax), %rax          # dereference the lambda's function
        jmp     *%rax                   #   pointer and call it

cdecl(gather_varargs):
        # %rsi contains the number of arguments to gather. This function is
        # called right at the beginning of executing a function body, so the
        # stack contains the following elements:
        #
        # %rsp - return address to caller of gather_varargs
        #        stack frame pushed by garlic_fncall
        #        return address to original caller of function
        #        first argument to original function
        #
        # The arguments to this function are:
        #
        # %rdi - number of required parameters for the original function
        # %rsi - number of total arguments passed to the original function
        #
        # Thus, (%rsi - %rdi) is the number of parameters that need to be
        # gathered.

        # Given N total arguments, we want to get to %rsp + 24 + ((N - 1) * 8).
        # The (N - 1) part accounts for the fact that we want to be just below
        # the last argument, not past it. With some algebraic manipulation, we
        # get %rsp + 16 + (N * 8).
        mov     %rsi, %r8               # take the total number of arguments
        shlq    $3, %r8                 # multiply by 8 (# of bytes per arg)
        mov     %rsp, %r9               # start at the top of the stack
        add     $16, %r9                # move to the start of the first
        add     %r8, %r9                #   argument put on the stack

        mov     %rsi, %r8               # compute the number of arguments that
        sub     %rdi, %r8               #   need to be gathered

        mov     $0, %rsi                # load nil as the last list element
        mov     %rsi, %r10              # %rsi will be used to store the list
gather_varargs_begin:                   #   so save the original value too
        cmp     $0, %r8                 # check that we have more arguments
        je      gather_varargs_done     # otherwise we're done

        mov     (%r9), %rdi             # grab the next argument
        push    %r8                     # save the number of arguments left
        push    %r9                     #   and the pseudo-stack pointer
        push    %r10                    #   and the total number of arguments
        call    cdecl(garlic_make_cons)
        mov     %rax, %rsi              # the cons is the next item in the list
        pop     %r10
        pop     %r9
        pop     %r8
        sub     $8, %r9                 # advance to the next argument
        sub     $1, %r8                 # we have one fewer argument to gather
        jmp     gather_varargs_begin    # loop
gather_varargs_done:
        mov     %rsi, %rax              # return the resulting list
        mov     %r10, %rsi              # restore the number of arguments
        ret

cdecl(garlic_call_function):
        mov     %rdx, %r12              # %r12 is callee-saved
        test    $1, %r12                # check if the number of arguments...
        jnz     garlic_call_function_odd_args # ...is even or odd
        sub     $8, %rsp                # align the stack if even
        add     $1, %r12                # remember that we aligned the stack
garlic_call_function_odd_args:
        shlq    $3, %r12                # multiply by 8 (# of bytes per arg)

        mov     %rdx, %r9               # start with the number of arguments
        sub     $1, %r9                 # subtract one to avoid fence-post
        shlq    $3, %r9                 # multiply by 8 (# of bytes per arg)
        add     %r9, %rsi               # this is the address of the last arg!
        mov     %rdx, %r8               # counter for number of arguments
garlic_call_function_begin:             # we'll push arguments in reverse order
        cmp     $0, %r8                 # when we've exhausted the args...
        je      garlic_call_function_done # ...finish the loop

        mov     (%rsi), %r10            # grab the current argument
        push    %r10                    # push it onto the stack
        sub     $8, %rsi                # go to the previous argument
        sub     $1, %r8                 # decrement the counter
        jmp     garlic_call_function_begin
garlic_call_function_done:
        mov     %rdx, %rsi              # garlic_fncall expects the second...
        call    cdecl(garlic_fncall)    # ...argument to be the number of args
        add     %r12, %rsp              # remove the arguments from the stack
        ret

cdecl(garlicval_to_int):
        # A tagged integer is specified by shifting it to the left by one bit,
        # then filling in the least significant bit with "1". When converting
        # back to a native integer, however, it is important that we do an
        # arithmetic right shift. That is, if the tagged value is negative (the
        # most significant bit is "1"), then the native integer should be
        # negative as well.
        #
        # According to http://stackoverflow.com/a/1857965, the bit shift
        # operator in C is not required to be an arithmetic shift, so to be
        # careful, we should force an arithmetic shift.
        sarq    $1, %rdi
        mov     %rdi, %rax
        ret
