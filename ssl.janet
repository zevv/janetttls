
(import /build/sslapi :as sslapi)

(varfn read [ssl] 0)

(defn write [ssl data]
  (def r (sslapi/write (ssl :sslsock) data))
  (case r
    :want-read (do (:read (ssl :sock) 0) (write ssl data))
    :want-write (do (:write (ssl :sock) "") (write ssl data)
    r)))

(varfn read [ssl]
  (def buffer (buffer/new 1024))
  (def r (sslapi/read (ssl :sslsock) buffer))
  (case r
    :want-read (do (:read (ssl :sock) 0) (read ssl))
    :want-write (do (:write (ssl :sock) "") (read ssl))
    buffer))


(def- ssl-proto @{
  :write write
  :read read
})

(defn connect [host port]
  (def sock (net/connect host port))
  (def sslsock (sslapi/set-ssl sock))
  (table/setproto ssl-proto @{ :sock sock :sslsock sslsock }))

