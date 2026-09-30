// ============================================================
// miller_rabin.cpp — deterministic Miller-Rabin for uint64
// ============================================================

#include "core/miller_rabin.hpp"

namespace {

uint64_t mulmod(uint64_t a, uint64_t b, uint64_t m) {
    return (unsigned __int128)a * b % m;
}

uint64_t powmod(uint64_t a, uint64_t e, uint64_t m) {
    uint64_t result = 1;
    a %= m;
    while (e > 0) {
        if (e & 1) result = mulmod(result, a, m);
        a = mulmod(a, a, m);
        e >>= 1;
    }
    return result;
}

} // anonymous namespace

bool voss_is_prime_mr(uint64_t n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0) return false;

    uint64_t d = n - 1;
    int r = 0;
    while ((d & 1) == 0) { d >>= 1; r++; }

    // Witnesses sufficient for all uint64
    static const uint64_t witnesses[] = {
        2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37
    };
    for (uint64_t a : witnesses) {
        if (a >= n) continue;
        uint64_t x = powmod(a, d, n);
        if (x == 1 || x == n - 1) continue;
        bool composite = true;
        for (int i = 0; i < r - 1; i++) {
            x = mulmod(x, x, n);
            if (x == n - 1) { composite = false; break; }
        }
        if (composite) return false;
    }
    return true;
}
