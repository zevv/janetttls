#!/usr/bin/env janet

(import ./ssl)
(import spork/http)


(defn server-handler [req]
  {:status 200 
   :headers {"Content-Type" "text/plain"} 
   :body "Hello, World!\r\n"})

(defn server []
  (def sock (ssl/listen "::" "8081"))
  (forever 
    (def client (ssl/accept sock))
    (http/server-handler client server-handler)
    ))

(ev/call server)
