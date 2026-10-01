// ============================================================
// mu.cpp — voss_numbers_mu (M6.2b)
//
// Moebius function:
//   mu(1) = 1
//   mu(n) = 0  if n has any squared prime factor
//   mu(n) = (-1)^k  where k = number of distinct primes, else
// ============================================================

#include <cstdint>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"
#include "numbers/factor_exponents.hpp"

extern "C" int voss_numbers_mu(uint64_t n, int* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n == 0) {
        voss_set_last_error("mu(0) is undefined; n must be >= 1");
        return VOSS_ERR_INVALID_N;
    }
    if (n == 1) { *out = 1; return VOSS_OK; }

    auto fe = voss_numbers_factor_exponents(n);
    if (fe.empty()) {
        voss_set_last_error("factorization failed");
        return VOSS_ERR_INTERNAL;
    }
    for (auto& pe : fe) {
        if (pe.second > 1) { *out = 0; return VOSS_OK; }
    }
    *out = (fe.size() % 2 == 0) ? 1 : -1;
    return VOSS_OK;
}
