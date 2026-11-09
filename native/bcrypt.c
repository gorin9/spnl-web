#define _GNU_SOURCE
#include <crypt.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
#include <string.h>
static _Thread_local char result[CRYPT_OUTPUT_SIZE];
const char *spnl_bcrypt_hash(const char *password, int cost) {
    unsigned char entropy[16]; char salt[CRYPT_GENSALT_OUTPUT_SIZE];
    struct crypt_data data = {0};
    if (cost < 4 || cost > 16 || strlen(password) > 72 || RAND_bytes(entropy, sizeof entropy) != 1) return "";
    if (!crypt_gensalt_rn("$2b$", (unsigned long)cost, (char *)entropy, sizeof entropy, salt, sizeof salt)) return "";
    char *hash = crypt_r(password, salt, &data);
    if (!hash || hash[0] == '*') return "";
    strncpy(result, hash, sizeof result - 1); result[sizeof result - 1] = 0;
    OPENSSL_cleanse(&data, sizeof data);
    return result;
}
int spnl_bcrypt_verify(const char *password, const char *stored) {
    struct crypt_data data = {0};
    size_t n = strlen(stored);
    if (strlen(password) > 72 || n != 60 || strncmp(stored,"$2",2) || stored[4] < '0' || stored[4] > '1' || (stored[4] == '1' && stored[5] > '6')) return 0;
    char *hash = crypt_r(password, stored, &data);
    int ok = hash && strlen(hash) == n && CRYPTO_memcmp(hash, stored, n) == 0;
    OPENSSL_cleanse(&data, sizeof data);
    return ok;
}
