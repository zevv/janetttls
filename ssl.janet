
(import /build/sslapi :as sslapi)

# Pump underlying SSL call until it is satisfied; the event queue is abused
# here by doing 0-byte net/read and net/write on the underlying socket.

(defn- ssl-handler [f stream & args]
  (def r (f (stream :ssl) ;args))
  (case r
    :syscall (do (print "syscall error") (os/exit 1))
    :want-read (do (:read (stream :sock) 0) (ssl-handler f stream ;args))
    :want-write (do (:write (stream :sock) "") (ssl-handler f stream ;args))
    buffer))

(defn- ssl-read [stream & args]
  (ssl-handler sslapi/read stream ;args))

(defn- ssl-write [stream & args]
  (ssl-handler sslapi/write stream ;args))

(defn- ssl-close [stream]
  (sslapi/close (stream :ssl))
  (:close (stream :sock)))

(def- ssl-proto @{
  :write ssl-write
  :read ssl-read
  :close ssl-close
})

# Wrap a net/stream in an ssl/stream

(defn- wrap-stream [sock &opt state cert key]
  (def stream @{ :sock sock :read ssl-read :write ssl-write :close ssl-close})
  (if state
    (set (stream :ssl) (sslapi/set-ssl sock state nil cert key)))
  stream)

# Public API

(defn listen [& args]
  (wrap-stream (net/listen ;args)))

(defn accept [stream cert key]
  (def client-sock (net/accept (stream :sock)))
  (def stream (wrap-stream client-sock :accept cert key))
  stream)

(defn connect [& args]
  (def stream (wrap-stream (net/connect ;args) :connect))
  stream)

