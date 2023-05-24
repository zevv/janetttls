
This is an experimental asynchronous OpenSSL TLS stream wrapper for Janet; it
abuses the event loop by doing zero byte `ev/read` and `ev/write` calls on the
underlying net stream, but then having OpenSSL perform the actual read and
write calls on the socket when the stream is readable or writable.

Tested on linux only:

```
jpm build && janet test.janet 
```

