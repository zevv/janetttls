
This is an experimental asynchronous OpenSSL TLS stream wrapper for Janet; it
abuses the event loop by doing zero byte `ev/read` and `ev/write` calls on the
underlying net stream, but then having OpenSSL perform the actual read and
write calls on the socket when the stream is readable or writable.

For now this needs a patched spork that uses polymorphic calls (`:read`,
`:write`, etc) for stearm I/O instead of depending on the event loop calls
`ev/read`, `ev/write`, etc:

https://github.com/zevv/spork/tree/polymorph-http

