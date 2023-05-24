
(import /build/openssl)

# Pump underlying SSL call until it is satisfied; the event queue is abused
# here by doing 0-byte net/read and net/write on the underlying socket.

(defn- tls-pump [f stream & args]
  (def result (f (stream :tls) ;args))
  (case result
    :want-read (do (:read (stream :sock) 0) (tls-pump f stream ;args))
    :want-write (do (:write (stream :sock) "") (tls-pump f stream ;args))
    :syscall (error "syscall error")
    result))

(defn read [stream & args]
  (tls-pump openssl/read stream ;args))

(defn chunk [stream & args]
  (tls-pump openssl/read stream ;args))

(defn write [stream & args]
  (tls-pump openssl/write stream ;args))

(defn close [stream]
  (openssl/close (stream :tls))
  (:close (stream :sock)))

(def- tls-proto @{
  :read read
  :chunk chunk
  :write write
  :close close
})

# Wrap a net/stream in an ssl/stream

(defn- wrap-stream [sock &opt state cert key]
  (def stream (table/setproto @{ :sock sock } tls-proto))
  (if state
    (set (stream :tls) (openssl/set-tls sock state nil cert key)))
  stream)

# Public API

(defn connect [& args]
  (wrap-stream (net/connect ;args) :client))

(defn listen [& args]
  (wrap-stream (net/listen ;args)))

(defn accept [stream cert key]
  (wrap-stream (net/accept (stream :sock)) :server cert key))

(defn server [host port &opt handler cert key]
  (def sock (listen host port))
  (forever 
    (def client (accept sock cert key))
    (ev/call (fn [] (handler client)))))
  
