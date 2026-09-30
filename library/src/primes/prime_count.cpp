// ============================================================
// prime_count.cpp — helpers + orchestration (M0)
// Helpers copied verbatim from src/voss_w30_v7.cu (v7-golden)
// Orchestration function voss_primes_prime_count() added on Day 6-7.
// ============================================================

#include <cstdint>
#include <cstdlib>

// === Wheel-30 constants (copied from v7-golden) ===
static const int W30[8] = {1, 7, 11, 13, 17, 19, 23, 29};

// === generate_base_primes (copied verbatim from v7-golden) ===
static void generate_base_primes(int limit, uint32_t** out, int* count) {
    bool* sieve = (bool*)malloc(limit + 1);
    for (int i = 0; i <= limit; i++) sieve[i] = true;
    sieve[0] = sieve[1] = false;
    for (int i = 2; (long long)i * i <= limit; i++)
        if (sieve[i])
            for (int j = i * i; j <= limit; j += i) sieve[j] = false;
    int cnt = 0;
    for (int i = 7; i <= limit; i++) if (sieve[i]) cnt++;
    uint32_t* arr = (uint32_t*)malloc(cnt * sizeof(uint32_t));
    int idx = 0;
    for (int i = 7; i <= limit; i++) if (sieve[i]) arr[idx++] = i;
    free(sieve);
    *out = arr; *count = cnt;
}

// === modinv (copied verbatim from v7-golden) ===
static int64_t modinv(int64_t a, int64_t m) {
    int64_t t = 0, newt = 1, r = m, newr = a % m;
    while (newr != 0) {
        int64_t q = r / newr;
        int64_t tmp = newt; newt = t - q * newt; t = tmp;
        tmp = newr; newr = r - q * newr; r = tmp;
    }
    if (t < 0) t += m;
    return t;
}
