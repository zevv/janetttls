#!/usr/bin/env janet

(import ./ssl)
(import spork/http)


(defn server-handler [req]
  {:status 200 
   :headers {"Content-Type" "text/plain"} 
   :body "Hello, World!\r\n"})


(defn server [addr port cert key]
  (printf "Listening on %s:%s" addr port)
  (def sock (ssl/listen addr port))
  (forever 
    (def client (ssl/accept sock cert key))
    (try
      (http/server-handler client server-handler)
      ([err fib] (print "Error: " err)))))


(defn ticks []
  (forever
    (print "tick")
    (ev/sleep 0.1)))

#(ev/call ticks)


(def cert (slurp "cert.pem"))
(def key (slurp "key.pem"))

(ev/call (fn [] (server "::" "8080" cert key)))
