// ============================================================
// sigma.cpp — voss_numbers_sigma (M6.2b)
//
// Divisor sum: sigma(n) = prod (p^(e+1) - 1) / (p - 1)
// Uses unsigned __int128 for the p^(e+1) intermediate to avoid
// overflow on large p with small e (e.g. n = p^2, p ~ 1e9).
// Result is checked against UINT64_MAX.
// ============================================================

#include <cstdint>
#include <climits>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"
#include "numbers/factor_exponents.hpp"

extern "C" int voss_numbers_sigma(uint64_t n, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n == 0) {
        voss_set_last_error("sigma(0) is undefined; n must be >= 1");
        return VOSS_ERR_INVALID_N;
    }
    if (n == 1) { *out = 1; return VOSS_OK; }

    auto fe = voss_numbers_factor_exponents(n);
    if (fe.empty()) {
        voss_set_last_error("factorization failed");
        return VOSS_ERR_INTERNAL;
    }

    unsigned __int128 result = 1;
    for (auto& pe : fe) {
        uint64_t p = pe.first;
        uint64_t e = pe.second;
        unsigned __int128 p_pow = 1;
        for (uint64_t i = 0; i <= e; i++) p_pow *= p;      // p^(e+1)
        unsigned __int128 term = (p_pow - 1) / (p - 1);    // geometric sum
        result *= term;
        if (result > (unsigned __int128)UINT64_MAX) {
            voss_set_last_error("sigma overflows uint64");
            return VOSS_ERR_OUT_OF_RANGE;
        }
    }
    *out = (uint64_t)result;
    return VOSS_OK;
}
