
#include <openssl/ssl.h>    
#include <openssl/err.h>    
#include <openssl/engine.h>

#include <janet.h>

struct sslsock {
    JanetStream *stream;
    SSL_CTX *ctx;
    SSL *ssl;
};


static Janet sslapi_set_ssl(int32_t argc, Janet *argv)
{
    janet_fixarity(argc, 1);
    JanetStream *stream = janet_getabstract(argv, 0, &janet_stream_type);

    SSL_library_init();
    SSL_load_error_strings();
    OpenSSL_add_all_algorithms();

    struct sslsock *ss = malloc(sizeof(struct sslsock));
    ss->stream = stream;
    ss->ctx = SSL_CTX_new(SSLv23_client_method());
    ss->ssl = SSL_new(ss->ctx);

    SSL_CTX_set_session_id_context(ss->ctx, (const unsigned char *)"janet", 5);
    SSL_set_fd(ss->ssl, stream->handle);
    SSL_set_connect_state(ss->ssl);

    return janet_wrap_pointer(ss);
}


static Janet handle_ssl_error(struct sslsock *ss, int r)
{
    int e = SSL_get_error(ss->ssl, r);
    if(e == SSL_ERROR_WANT_READ) return janet_ckeywordv("want-read");
    if(e == SSL_ERROR_WANT_WRITE) return janet_ckeywordv("want-write");
    if(e == SSL_ERROR_SYSCALL) return janet_ckeywordv("syscall");
    e = ERR_get_error();
    return janet_wrap_string(ERR_reason_error_string(r));
}


static Janet sslapi_write(int32_t argc, Janet *argv)
{
    janet_fixarity(argc, 2);
    struct sslsock *ss = janet_getpointer(argv, 0);
    JanetByteView view = janet_getbytes(argv, 1);
    int r = SSL_write(ss->ssl, view.bytes, view.len);
    if(r < 0) {
        return handle_ssl_error(ss, r);
    }
    return janet_wrap_integer(r);
}


static Janet sslapi_read(int32_t argc, Janet *argv)
{
    janet_fixarity(argc, 2);
    struct sslsock *ss = janet_getpointer(argv, 0);
    JanetBuffer *buffer = janet_getbuffer(argv, 1);
    int r = SSL_read(ss->ssl, buffer->data, buffer->capacity);
    if(r < 0) {
        return handle_ssl_error(ss, r);
    } 
    buffer->count = r;
    return janet_wrap_integer(r);
}


static const JanetReg cfuns[] = {
    {"set-ssl", sslapi_set_ssl, "(sslapi/set_ssl)"},
    {"write", sslapi_write, "(sslapi/write)"},
    {"read", sslapi_read, "(sslapi/read)"},
    {NULL, NULL, NULL}
};


JANET_MODULE_ENTRY(JanetTable *env) {
    janet_cfuns(env, "mymod", cfuns);
}


// vi: ts=4 sw=4 et
