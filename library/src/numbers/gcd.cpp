// ============================================================
// gcd.cpp — voss_numbers_gcd (M6.2c)
//
// Greatest common divisor via Euclid's algorithm.
// Convention: gcd(a, 0) = a, gcd(0, b) = b, gcd(0, 0) = 0.
// ============================================================

#include <cstdint>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"

extern "C" int voss_numbers_gcd(uint64_t a, uint64_t b, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    while (b) { uint64_t t = b; b = a % b; a = t; }
    *out = a;
    return VOSS_OK;
}
