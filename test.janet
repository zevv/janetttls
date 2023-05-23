#!/usr/bin/env janet

(import ./ssl)

(def req "
GET /div/slow.cgi HTTP/1.0\r\n
Host: zevv.nl\r\n
\r\n
")

(pp req)

(defn hello []
  (def sock (ssl/connect "zevv.nl" "https"))
  (def r (:write sock req))
  (forever 
    (def b (:read sock))
    (if (empty? b) (break))
    (print b)))



(defn ticks []
  (forever
    (print "tick")
    (ev/sleep 0.1)))

(ev/call ticks)
(ev/call hello)
