#!/usr/bin/env janet

(import /tls)

# OpenSSL does not use MSG_NOSIGNAL on send(), so we need to ignore
# SIGPIPE to avoid crashing when the peer closes the connection
(ffi/context nil)
(ffi/defbind signal :ptr [signum :int handler :long])
(signal 13 1)

# Start a TLS socket server that reads (and ignores) a HTTP request
# and sends a number of "tick" messages to the client before closing
(defn server [addr port cert key]
  (printf "HTTPS server listening on port 8080")
  (def sock (tls/listen addr port))
  (forever 
    (def client (tls/accept sock cert key))
    (ev/call (fn []
      (protect
        (print (:read client 4096 @""))
        (:write client "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello, World!\r\n")
        (for i 1 10
          (ev/sleep 0.25)
          (:write client (string "tick " i "\r\n")))
        (:close client))))))

# Connect to the TLS server and send a HTTP request, then read the
# response until the server closes the connection
(defn client [addr port]
  (ev/sleep 0.5)
  (def sock (tls/connect addr port))
  (:write sock "GET / HTTP/1.1\r\n\r\n")
  (protect (while
      (def resp (:read sock 4096 @""))
      (print resp)))
  (tls/close sock))

# Read cert+key and start server
(def cert (slurp "cert.pem"))
(def key (slurp "key.pem"))
(ev/call (fn [] (server "::" "8080" cert key)))

# Start a client talking to our own server
(ev/call (fn [] (client "localhost" "8080")))

