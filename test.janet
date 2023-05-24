#!/usr/bin/env janet

(import ./ssl)


(defn server [addr port cert key]
  (printf "HTTPS server listening on port 8080")
  (def sock (ssl/listen addr port))
  (forever 
    (def client (ssl/accept sock cert key))
    (ev/call (fn []
        (print (:read client 4096 @""))
        (:write client "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello, World!\r\n")
        (print "ticking")
        (for i 1 10
          (ev/sleep 0.25)
          (:write client (string "Tick " i "\r\n")))
        (print "closing")
        (:close client)))))

(defn client [addr port]
  (ev/sleep 0.5)
  (def sock (ssl/connect addr port))
  (:write sock "GET / HTTP/1.1\r\n\r\n")
  (protect (while
      (def resp (:read sock 4096 @""))
      (printf "Got response: %m" resp)))
  (ssl/close sock))


(def cert (slurp "cert.pem"))
(def key (slurp "key.pem"))

(ev/call (fn [] (server "::" "8080" cert key)))
(ev/call (fn [] (client "localhost" "8080")))

