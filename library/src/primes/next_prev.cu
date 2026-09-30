// ============================================================
// next_prev.cu — voss_primes_next / voss_primes_prev (M3)
//
// Small helper functions using CPU Miller-Rabin for local search.
// ============================================================

#include <cstdint>
#include <cmath>
#include <string>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

namespace {

const uint64_t MAX_SEARCH = 100000000ULL;  // 10^8 max search distance

} // anonymous namespace

extern "C" int voss_primes_next(uint64_t x, uint64_t* out_prime) {
    if (out_prime == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (x < 2) {
        // Next prime after x < 2 is 2
        *out_prime = 2;
        return VOSS_OK;
    }

    // Skip even numbers (start from odd or x+1)
    uint64_t candidate = x + 1;
    if (candidate == 2) { *out_prime = 2; return VOSS_OK; }
    if (candidate % 2 == 0) candidate++;

    uint64_t steps = 0;
    while (steps < MAX_SEARCH) {
        if (voss_is_prime_mr(candidate)) {
            *out_prime = candidate;
            return VOSS_OK;
        }
        candidate += 2;
        steps += 2;
    }
    voss_set_last_error("no prime found within search limit");
    return VOSS_ERR_OUT_OF_RANGE;
}

extern "C" int voss_primes_prev(uint64_t x, uint64_t* out_prime) {
    if (out_prime == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (x <= 2) {
        voss_set_last_error("no prime < " + std::to_string(x));
        return VOSS_ERR_INVALID_N;
    }
    if (x == 3) { *out_prime = 2; return VOSS_OK; }

    // Start below x, ensure odd
    uint64_t candidate = x - 1;
    if (candidate == 2) { *out_prime = 2; return VOSS_OK; }
    if (candidate % 2 == 0) candidate--;

    uint64_t steps = 0;
    while (steps < MAX_SEARCH && candidate >= 3) {
        if (voss_is_prime_mr(candidate)) {
            *out_prime = candidate;
            return VOSS_OK;
        }
        if (candidate < 2) break;
        candidate -= 2;
        steps += 2;
    }
    if (candidate < 2) {
        *out_prime = 2;
        return VOSS_OK;
    }
    voss_set_last_error("no prime found within search limit");
    return VOSS_ERR_OUT_OF_RANGE;
}
