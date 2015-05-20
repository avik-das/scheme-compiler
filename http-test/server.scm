(require http)
(require html)

(define *port* 9000)

(define (handle-request)
  (display "handling request")
  (newline)
  (html:html
    (html:head "Garlic HTTP Demo")
    (html:body
      (html:p
        "This web page is served by the HTTP server available in the garlic\n"
        "distribution. The HTML is generated by a garlic function.")
      (html:p
        "If you're interested in learning more about garlic, please visit "
        (html:a
          'href "http://github.com/avik-das/garlic"
          "the garlic Github repository")
        ".")
      (html:img
        'src "http://i.imgur.com/NFS0WeC.jpg"
        'width "320"
        'height "427")
      (html:p "(image courtesy of imgur)"))) )

(http:serve *port* handle-request)
