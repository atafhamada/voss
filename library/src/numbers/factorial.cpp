// ============================================================
// factorial.cpp — voss_numbers_factorial (M6.2c)
//
// Iterative product. 0! = 1.
// Domain: n <= 20 (21! = 51090942171709440000 > UINT64_MAX).
// ============================================================

#include <cstdint>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"

extern "C" int voss_numbers_factorial(uint64_t n, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n > 20) {
        voss_set_last_error("factorial(n) overflows uint64 for n >= 21");
        return VOSS_ERR_OUT_OF_RANGE;
    }
    uint64_t r = 1;
    for (uint64_t i = 2; i <= n; i++) r *= i;
    *out = r;
    return VOSS_OK;
}
