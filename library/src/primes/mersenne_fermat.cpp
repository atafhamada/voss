// ============================================================
// mersenne_fermat.cpp — M5.3
//
// Mersenne primes: M_p = 2^p - 1, tested via Lucas-Lehmer
// Fermat primes:   F_n = 2^(2^n) + 1
// ============================================================

#include <cstdint>
#include <stdexcept>
#include <string>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

namespace {

// ============================================================
// Lucas-Lehmer: M_p = 2^p - 1 is prime iff s_{p-2} == 0 mod M_p,
// where s_0 = 4, s_{k+1} = s_k^2 - 2.
// Requires p <= 63 for uint64 arithmetic.
// ============================================================
bool lucas_lehmer(uint32_t p) {
    if (p == 2) return true;   // M_2 = 3 (prime)
    if (p < 2) return false;
    if (p == 3) return true;   // M_3 = 7 (prime)
    if (p == 5) return true;   // M_5 = 31 (prime)
    if (p == 7) return true;   // M_7 = 127 (prime)

    uint64_t M = (1ULL << p) - 1;  // requires p <= 63
    uint64_t s = 4;
    for (uint32_t k = 0; k < p - 2; k++) {
        // s = (s*s - 2) mod M, using __int128 to avoid overflow
        unsigned __int128 ss = (unsigned __int128)s * s;
        ss = ss - 2;
        s = (uint64_t)(ss % M);
    }
    return s == 0;
}

} // anonymous namespace

extern "C" int voss_primes_is_mersenne_prime(uint32_t p, int* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (p < 2) {
        voss_set_last_error("p must be >= 2");
        return VOSS_ERR_INVALID_N;
    }
    if (p > 63) {
        voss_set_last_error("p must be <= 63 (uint64 limit)");
        return VOSS_ERR_OUT_OF_RANGE;
    }
    *out = lucas_lehmer(p) ? 1 : 0;
    return VOSS_OK;
}

extern "C" int voss_primes_is_fermat_prime(uint32_t n, int* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n > 5) {
        voss_set_last_error("n must be <= 5 (uint64 limit for 2^(2^n)+1)");
        return VOSS_ERR_OUT_OF_RANGE;
    }

    // F_n = 2^(2^n) + 1
    uint64_t value;
    if (n == 0)      value = 3;
    else if (n == 1) value = 5;
    else if (n == 2) value = 17;
    else if (n == 3) value = 257;
    else if (n == 4) value = 65537;
    else /* n == 5 */ value = (uint64_t)4294967297ULL;

    // Use Miller-Rabin for the primality test
    *out = voss_is_prime_mr(value) ? 1 : 0;
    return VOSS_OK;
}
