#ifndef VOSS_NUMBERS_FACTOR_EXPONENTS_HPP
#define VOSS_NUMBERS_FACTOR_EXPONENTS_HPP

#include <cstdint>
#include <cstdlib>
#include <utility>
#include <vector>

#include "voss/voss.h"
#include "voss/voss_primes.h"

// Internal helper (M6.2b): prime factorization as (prime, exponent) pairs,
// primes sorted ascending. Reuses voss_primes_factorize (M5.2).
// Returns empty vector for n < 2 or on error.
inline std::vector<std::pair<uint64_t, uint64_t>>
voss_numbers_factor_exponents(uint64_t n) {
    if (n < 2) return {};
    uint64_t* raw = nullptr;
    uint64_t cnt = 0;
    int rc = voss_primes_factorize(n, &raw, &cnt);
    if (rc != VOSS_OK || raw == nullptr || cnt == 0) {
        if (raw) free(raw);
        return {};
    }
    std::vector<std::pair<uint64_t, uint64_t>> out;
    uint64_t i = 0;
    while (i < cnt) {
        uint64_t p = raw[i];
        uint64_t e = 0;
        while (i < cnt && raw[i] == p) { e++; i++; }
        out.emplace_back(p, e);
    }
    free(raw);
    return out;
}

#endif // VOSS_NUMBERS_FACTOR_EXPONENTS_HPP
