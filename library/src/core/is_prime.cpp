// ============================================================
// is_prime.cpp — voss_primes_is_prime C ABI
// ============================================================

#include <cstdint>
#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

extern "C" int voss_primes_is_prime(uint64_t x, int* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    *out = voss_is_prime_mr(x) ? 1 : 0;
    return VOSS_OK;
}
