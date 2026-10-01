// ============================================================
// phi.cpp — voss_numbers_phi (M6.2a)
//
// Euler's totient:
//   phi(n) = n * prod_{p | n} (p - 1) / p
// Distinct primes via voss_primes_factorize (M5.2).
// ============================================================

#include <cstdint>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"
#include "numbers/distinct_factors.hpp"

extern "C" int voss_numbers_phi(uint64_t n, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n == 0) {
        voss_set_last_error("phi(0) is undefined; n must be >= 1");
        return VOSS_ERR_INVALID_N;
    }
    if (n == 1) { *out = 1; return VOSS_OK; }

    auto primes = voss_numbers_distinct_primes(n);
    if (primes.empty()) {
        voss_set_last_error("factorization failed");
        return VOSS_ERR_INTERNAL;
    }
    uint64_t result = n;
    for (uint64_t p : primes) {
        result = (result / p) * (p - 1);
    }
    *out = result;
    return VOSS_OK;
}
