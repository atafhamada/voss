// ============================================================
// nth.cu — voss_primes_nth (M3)
//
// Returns the nth prime (1-indexed: nth(1)=2, nth(2)=3, ...).
//
// Strategy:
//  - For small n (n <= 100000), use a segmented CPU sieve
//  - For larger n, use the existing VOSS Context pipeline
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <string>
#include <stdexcept>
#include <vector>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"

namespace {

// ============================================================
// CPU Miller-Rabin primality test (deterministic for 64-bit)
// ============================================================
uint64_t mulmod(uint64_t a, uint64_t b, uint64_t m) {
    return (unsigned __int128)a * b % m;
}

uint64_t powmod(uint64_t a, uint64_t e, uint64_t m) {
    uint64_t result = 1;
    a %= m;
    while (e > 0) {
        if (e & 1) result = mulmod(result, a, m);
        a = mulmod(a, a, m);
        e >>= 1;
    }
    return result;
}

bool is_prime_mr(uint64_t n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0) return false;

    uint64_t d = n - 1;
    int r = 0;
    while ((d & 1) == 0) { d >>= 1; r++; }

    // Deterministic witnesses for 64-bit integers
    static const uint64_t witnesses[] = {
        2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37
    };
    for (uint64_t a : witnesses) {
        if (a >= n) continue;
        uint64_t x = powmod(a, d, n);
        if (x == 1 || x == n - 1) continue;
        bool composite = true;
        for (int i = 0; i < r - 1; i++) {
            x = mulmod(x, x, n);
            if (x == n - 1) { composite = false; break; }
        }
        if (composite) return false;
    }
    return true;
}

// ============================================================
// CPU segmented sieve up to a limit
// Returns first `count` primes as a vector.
// ============================================================
std::vector<uint64_t> first_n_primes(uint64_t count) {
    std::vector<uint64_t> primes;
    primes.reserve(count);

    if (count == 0) return primes;

    // For small counts, use brute-force with Miller-Rabin
    if (count <= 100000) {
        uint64_t n = 2;
        while (primes.size() < count) {
            if (is_prime_mr(n)) primes.push_back(n);
            n++;
        }
        return primes;
    }

    // Larger count — use trial division to a rough bound then extend
    // Upper bound estimate for nth prime (n >= 6): n*(log n + log log n)
    double nf = (double)count;
    uint64_t upper_bound = (uint64_t)(nf * (std::log(nf) + std::log(std::log(nf))) * 1.3) + 100;

    std::vector<bool> sieve(upper_bound + 1, true);
    sieve[0] = sieve[1] = false;
    for (uint64_t i = 2; i * i <= upper_bound; i++) {
        if (sieve[i]) {
            for (uint64_t j = i * i; j <= upper_bound; j += i) sieve[j] = false;
        }
    }
    for (uint64_t i = 2; i <= upper_bound && primes.size() < count; i++) {
        if (sieve[i]) primes.push_back(i);
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
    if (n > 50000000ULL) {  // 50M -> prime ~ 982M — feasible for CPU sieve
        voss_set_last_error("n exceeds maximum (50,000,000)");
        return VOSS_ERR_OUT_OF_RANGE;
    }

    try {
        // Threshold: use Context for large n (uses GPU), else CPU
        if (n <= 100000) {
            std::vector<uint64_t> primes = first_n_primes(n);
            if (primes.size() < n) {
                voss_set_last_error("internal: could not find n primes");
                return VOSS_ERR_INTERNAL;
            }
            *out_prime = primes[n - 1];
            return VOSS_OK;
        }

        // Large n: use Context with binary-search style approach
        // Estimate upper bound for nth prime
        double nf = (double)n;
        uint64_t est = (uint64_t)(nf * (std::log(nf) + std::log(std::log(nf))) * 1.3) + 100;

        // Round est to a segment-friendly value
        while (est > 0 && est < 100000000000000ULL) {
            voss_primes_ctx* ctx = nullptr;
            int rc = voss_primes_ctx_new(est, VOSS_PROFILE_MINIMAL, &ctx);
            if (rc != VOSS_OK) { est *= 2; continue; }

            uint64_t count = 0;
            rc = voss_primes_ctx_prime_count(ctx, &count);
            voss_primes_ctx_free(ctx);

            if (rc != VOSS_OK) { est *= 2; continue; }

            if (count >= n) break;
            est *= 2;
            if (est > 100000000000000ULL) {
                voss_set_last_error("n too large for current implementation");
                return VOSS_ERR_OUT_OF_RANGE;
            }
        }

        // We have est such that pi(est) >= n.
        // Binary search for smallest x with pi(x) >= n, but pi(x) is expensive.
        // Instead, use a linear scan from est downward via Miller-Rabin on each
        // candidate is too slow. Simpler: use CPU to sieve a window around est.
        // For n up to 50M, prime ~ 982M — CPU sieve of ~1B booleans is 1 GB.
        // Use a lighter approach: sieve up to est and count.
        std::vector<bool> sieve(est + 1, true);
        sieve[0] = sieve[1] = false;
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
