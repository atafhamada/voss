#ifndef VOSS_NUMBERS_DISTINCT_FACTORS_HPP
#define VOSS_NUMBERS_DISTINCT_FACTORS_HPP

#include <cstdint>
#include <cstdlib>
#include <vector>

#include "voss/voss.h"
#include "voss/voss_primes.h"

// Internal helper (M6.2a): distinct prime factors of n, sorted ascending.
// Reuses voss_primes_factorize (M5.2: Pollard rho + Miller-Rabin).
// Returns empty vector on error.
inline std::vector<uint64_t> voss_numbers_distinct_primes(uint64_t n) {
    uint64_t* raw = nullptr;
    uint64_t cnt = 0;
    int rc = voss_primes_factorize(n, &raw, &cnt);
    if (rc != VOSS_OK || raw == nullptr || cnt == 0) {
        if (raw) free(raw);
        return {};
    }
    std::vector<uint64_t> out;
    out.reserve(cnt);
    uint64_t prev = 0;
    for (uint64_t i = 0; i < cnt; i++) {
        if (raw[i] != prev) { out.push_back(raw[i]); prev = raw[i]; }
    }
    free(raw);
    return out;
}

#endif // VOSS_NUMBERS_DISTINCT_FACTORS_HPP
