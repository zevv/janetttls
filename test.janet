#!/usr/bin/env janet

(import ./ssl)
(import spork/http)


(defn server-handler [req]
  (printf "Got request: %m" req)
  {:status 200 
   :headers {"Content-Type" "text/plain"} 
   :body "Hello, World!\r\n"})


(defn server [addr port cert key]
  (printf "HTTPS server listening on port 8080")
  (def sock (ssl/listen addr port))
  (forever 
    (def client (ssl/accept sock cert key))
    (ev/call (fn [] (try
        (http/server-handler client server-handler)
        ([err fib] (print "Error: " err)))))))


(defn ticks []
  (forever
    (print "tick")
    (ev/sleep 0.1)))

#(ev/call ticks)


(def cert (slurp "cert.pem"))
(def key (slurp "key.pem"))

(ev/call (fn [] (server "::" "8080" cert key)))
