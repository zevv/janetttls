
#include <openssl/ssl.h>    
#include <openssl/err.h>    
#include <openssl/engine.h>

#include <janet.h>

struct sslsock {
    SSL_CTX *ctx;
    SSL *ssl;
};


#define CHECK_SSL(expr, msg) if(!(expr)) janet_panicf("error %s :%s\n", msg, ERR_reason_error_string(ERR_get_error()));

static Janet sslapi_set_ssl(int32_t argc, Janet *argv)
{
    static int initialized = 0;
    if(!initialized) {
        SSL_library_init();
        SSL_load_error_strings();
        OpenSSL_add_all_algorithms();
        initialized = 1;
    }

    JanetStream *stream = janet_getabstract(argv, 0, &janet_stream_type);
    const char *state = janet_getkeyword(argv, 1);
    JanetBuffer *ca = janet_optbuffer(argv, argc, 2, 0);
    JanetBuffer *cert = janet_optbuffer(argv, argc, 3, 0);
    JanetBuffer *key = janet_optbuffer(argv, argc, 4, 0);

    janet_arity(argc, 2, 5);
    struct sslsock *ss = malloc(sizeof(struct sslsock));
    ss->ctx = SSL_CTX_new(TLS_method());

    if(ca->count > 0) {
        BIO *bio = BIO_new_mem_buf(ca->data, ca->count);
        X509 *x = PEM_read_bio_X509(bio ,NULL, NULL, NULL);
        BIO_free(bio);
        CHECK_SSL(x != NULL, "reading ca");
        X509_STORE* store = SSL_CTX_get_cert_store(ss->ctx);
        int r = X509_STORE_add_cert(store, x);
        X509_free(x);
        CHECK_SSL(r == 1, "reading ca");
    } else {
        int r = SSL_CTX_load_verify_locations(ss->ctx, NULL, "/etc/ssl/certs");
        CHECK_SSL(r == 1, "Error reading CA");
    }

    if(cert->count > 0) {
        BIO *bio = BIO_new_mem_buf(cert->data, cert->count);
        X509 *x = PEM_read_bio_X509(bio ,NULL, NULL, NULL);
        BIO_free(bio);
        CHECK_SSL(x != NULL, "reading cert");
        int r = SSL_CTX_use_certificate(ss->ctx, x);
        X509_free(x);
        CHECK_SSL(r == 1, "reading cert");
    }

    if(key->count > 0) {
        BIO *bio = BIO_new_mem_buf(key->data, key->count);
        EVP_PKEY *pkey = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
        BIO_free(bio);
        CHECK_SSL(pkey != NULL, "reading private key");
        int r = SSL_CTX_use_PrivateKey(ss->ctx, pkey);
        EVP_PKEY_free(pkey);
        CHECK_SSL(r == 1, "reading private key");
    }

    SSL_CTX_set_session_id_context(ss->ctx, (const unsigned char *)"janet", 5);

    ss->ssl = SSL_new(ss->ctx);
    SSL_set_fd(ss->ssl, stream->handle);

    if(strcmp(state, "client") == 0) {
        SSL_set_connect_state(ss->ssl);
    }
    if(strcmp(state, "server") == 0) {
        SSL_set_accept_state(ss->ssl);
    }

    return janet_wrap_pointer(ss);
}


static Janet handle_ssl_error(struct sslsock *ss, int r)
{
    int e = SSL_get_error(ss->ssl, r);
    if(e == SSL_ERROR_WANT_READ) return janet_ckeywordv("want-read");
    if(e == SSL_ERROR_WANT_WRITE) return janet_ckeywordv("want-write");
    if(e == SSL_ERROR_SYSCALL) return janet_ckeywordv("syscall");
    e = ERR_get_error();
    if(e > 0) {
        janet_panicf("SSL error: %s", janet_cstring(ERR_reason_error_string(e)));
    } else {
        janet_panicf("SSL error: unknown error");
    }
    return janet_wrap_nil();
}


static Janet sslapi_write(int32_t argc, Janet *argv)
{
    janet_fixarity(argc, 2);
    struct sslsock *ss = janet_getpointer(argv, 0);
    JanetByteView view = janet_getbytes(argv, 1);
    int r = SSL_write(ss->ssl, view.bytes, view.len);
    if(r > 0)  {
        return janet_wrap_nil();
    } else {
        return handle_ssl_error(ss, r);
    }
}


static Janet sslapi_read(int32_t argc, Janet *argv)
{
    janet_fixarity(argc, 3);
    struct sslsock *ss = janet_getpointer(argv, 0);
    int count = janet_getinteger(argv, 1);
    JanetBuffer *buffer = janet_getbuffer(argv, 2);
    janet_buffer_extra(buffer, count);
    int r = SSL_read(ss->ssl, buffer->data + buffer->count, count);
    if(r > 0) {
        buffer->count += r;
        return janet_wrap_buffer(buffer);
    } else {
        return handle_ssl_error(ss, r);
    }
}


static Janet sslapi_close(int32_t argc, Janet *argv)
{
    janet_fixarity(argc, 1);
    struct sslsock *ss = janet_getpointer(argv, 0);
    SSL_free(ss->ssl);
    SSL_CTX_free(ss->ctx);
    return janet_wrap_nil();
}


static const JanetReg cfuns[] = {
    {"set-ssl", sslapi_set_ssl, "(sslapi/set_ssl)"},
    {"write", sslapi_write, "(sslapi/write)"},
    {"read", sslapi_read, "(sslapi/read)"},
    {"close", sslapi_close, "(sslapi/close)"},
    {NULL, NULL, NULL}
};


JANET_MODULE_ENTRY(JanetTable *env) {
    janet_cfuns(env, "sslapi", cfuns);
}


// vi: ts=4 sw=4 et
