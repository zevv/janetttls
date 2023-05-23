
(import /build/sslapi :as sslapi)

(def cert (slurp "cert.pem"))
(def key (slurp "key.pem"))

(varfn ssl-read [stream] 0)

(defn ssl-write [stream data &opt timeout]
  (def r (sslapi/write (stream :ssl) data))
  (case r
    :want-read (do (:read (stream :sock) 0) (ssl-write stream data timeout))
    :want-write (do (:write (stream :sock) "") (ssl-write stream data timeout)
    r)))

(varfn ssl-read [stream count &opt buffer timeout]
  (default buffer (buffer/new count))
  (def r (sslapi/read (stream :ssl) buffer count))
  (case r
    :syscall (do (print "syscall error") (os/exit 1))
    :want-read (do (:read (stream :sock) 0) (ssl-read stream count buffer timeout))
    :want-write (do (:write (stream :sock) "") (ssl-read stream count buffer timeout))
    buffer))

(defn ssl-close [stream]
  (sslapi/close (stream :ssl))
  (:close (stream :sock)))

(def- ssl-proto @{
  :write ssl-write
  :read ssl-read
  :close ssl-close
})

(defn- wrap [sock &opt state]
  (def stream @{ :sock sock :read ssl-read :write ssl-write :close ssl-close})
  (if state
    (set (stream :ssl) (sslapi/set-ssl sock state "" (string cert) (string key))))
  stream)


(defn listen [& args]
  (wrap (net/listen ;args)))

(defn accept [stream]
  (printf "Accept on %p" (stream :sock))
  (def client-sock (net/accept (stream :sock)))
  (def stream (wrap client-sock :accept))
  stream)

(defn connect [& args]
  (def stream (wrap (net/connect ;args) :connect))
  stream)

