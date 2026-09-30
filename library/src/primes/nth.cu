// ============================================================
// nth.cu — voss_primes_nth (M3)
//
// Returns the nth prime (1-indexed: nth(1)=2, nth(2)=3, ...).
//
// Strategy:
//  - For small n (n <= 100000), use brute force with Miller-Rabin
//  - For larger n, sieve up to estimated upper bound
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <string>
#include <vector>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

namespace {

// Brute-force: find first `count` primes using Miller-Rabin.
std::vector<uint64_t> first_n_primes(uint64_t count) {
    std::vector<uint64_t> primes;
    primes.reserve(count);
    if (count == 0) return primes;

    uint64_t n = 2;
    while (primes.size() < count) {
        if (voss_is_prime_mr(n)) primes.push_back(n);
        n++;
    }
    return primes;
}

} // anonymous namespace

extern "C" int voss_primes_nth(uint64_t n, uint64_t* out_prime) {
    if (out_prime == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n == 0) {
        voss_set_last_error("n must be >= 1 (1-indexed)");
        return VOSS_ERR_INVALID_N;
    }
    if (n > 50000000ULL) {
        voss_set_last_error("n exceeds maximum (50,000,000)");
        return VOSS_ERR_OUT_OF_RANGE;
    }

    try {
        // Small n: brute force with Miller-Rabin
        if (n <= 100000) {
            std::vector<uint64_t> primes = first_n_primes(n);
            if (primes.size() < n) {
                voss_set_last_error("internal: could not find n primes");
                return VOSS_ERR_INTERNAL;
            }
            *out_prime = primes[n - 1];
            return VOSS_OK;
        }

        // Large n: estimate upper bound and sieve on CPU
        double nf = (double)n;
        uint64_t est = (uint64_t)(nf * (std::log(nf) + std::log(std::log(nf))) * 1.3) + 100;

        // Cap to avoid excessive memory
        if (est > 5000000000ULL) {
            voss_set_last_error("internal: estimate too large");
            return VOSS_ERR_OUT_OF_RANGE;
        }

        std::vector<bool> sieve(est + 1, true);
        if (est >= 0) sieve[0] = false;
        if (est >= 1) sieve[1] = false;
        for (uint64_t i = 2; i * i <= est; i++) {
            if (sieve[i]) {
                for (uint64_t j = i * i; j <= est; j += i) sieve[j] = false;
            }
        }
        uint64_t count = 0;
        for (uint64_t i = 2; i <= est; i++) {
            if (sieve[i]) {
                count++;
                if (count == n) {
                    *out_prime = i;
                    return VOSS_OK;
                }
            }
        }
        voss_set_last_error("internal: could not locate nth prime");
        return VOSS_ERR_INTERNAL;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_CUDA;
    } catch (...) {
        voss_set_last_error("Unknown error");
        return VOSS_ERR_INTERNAL;
    }
}
