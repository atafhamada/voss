// ============================================================
// tau.cpp — voss_numbers_tau (M6.2b)
//
// Divisor count: tau(n) = prod (e_i + 1)
// Exponents via voss_numbers_factor_exponents (M6.2b).
// ============================================================

#include <cstdint>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"
#include "numbers/factor_exponents.hpp"

extern "C" int voss_numbers_tau(uint64_t n, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n == 0) {
        voss_set_last_error("tau(0) is undefined; n must be >= 1");
        return VOSS_ERR_INVALID_N;
    }
    if (n == 1) { *out = 1; return VOSS_OK; }

    auto fe = voss_numbers_factor_exponents(n);
    if (fe.empty()) {
        voss_set_last_error("factorization failed");
        return VOSS_ERR_INTERNAL;
    }
    uint64_t result = 1;
    for (auto& pe : fe) {
        result *= (pe.second + 1);
    }
    *out = result;
    return VOSS_OK;
}
