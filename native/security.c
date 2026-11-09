#include <openssl/crypto.h>
#include <string.h>
int spnl_secure_equal(const char *a, size_t n, const char *b, size_t m) {
    return n == m && CRYPTO_memcmp(a, b, n) == 0;
}
