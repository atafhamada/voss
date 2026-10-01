// ============================================================
// lcm.cpp — voss_numbers_lcm (M6.2c)
//
// Least common multiple via gcd: lcm(a, b) = (a / gcd(a, b)) * b.
// Convention: lcm(0, k) = lcm(k, 0) = lcm(0, 0) = 0.
// Overflow check: (a/g) * b > UINT64_MAX -> VOSS_ERR_OUT_OF_RANGE.
// ============================================================

#include <cstdint>
#include <climits>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"

extern "C" int voss_numbers_lcm(uint64_t a, uint64_t b, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (a == 0 || b == 0) { *out = 0; return VOSS_OK; }

    // compute g = gcd(a,b) inline (avoid calling gcd symbol from here)
    uint64_t x = a, y = b;
    while (y) { uint64_t t = y; y = x % y; x = t; }
    uint64_t g = x;

    uint64_t a_over_g = a / g;
    if (a_over_g > UINT64_MAX / b) {
        voss_set_last_error("lcm overflow: (a/gcd)*b > UINT64_MAX");
        return VOSS_ERR_OUT_OF_RANGE;
    }
    *out = a_over_g * b;
    return VOSS_OK;
}
