
(import /build/sslapi :as sslapi)

# Pump underlying SSL call until it is satisfied; the event queue is abused
# here by doing 0-byte net/read and net/write on the underlying socket.

(defn- ssl-handler [f stream & args]
  (def result (f (stream :ssl) ;args))
  (case result
    :want-read (do (:read (stream :sock) 0) (ssl-handler f stream ;args))
    :want-write (do (:write (stream :sock) "") (ssl-handler f stream ;args))
    :syscall (do (print "syscall error") (os/exit 1))
    result))

(defn read [stream & args]
  (ssl-handler sslapi/read stream ;args))

(defn chunk [stream & args]
  (ssl-handler sslapi/read stream ;args))

(defn write [stream & args]
  (ssl-handler sslapi/write stream ;args))

(defn close [stream]
  (sslapi/close (stream :ssl))
  (:close (stream :sock)))

(def- ssl-proto @{
  :read read
  :chunk chunk
  :write write
  :close close
})

# Wrap a net/stream in an ssl/stream

(defn- wrap-stream [sock &opt state cert key]
  (def stream (table/setproto @{ :sock sock } ssl-proto))
  (if state
    (set (stream :ssl) (sslapi/set-ssl sock state nil cert key)))
  stream)

# Public API

(defn listen [& args]
  (wrap-stream (net/listen ;args)))

(defn accept [stream cert key]
  (wrap-stream (net/accept (stream :sock)) :server cert key))

(defn connect [& args]
  (wrap-stream (net/connect ;args) :client))

