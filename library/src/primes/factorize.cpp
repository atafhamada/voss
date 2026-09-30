// ============================================================
// factorize.cpp — voss_primes_factorize (M5.2)
//
// Factorization using trial division + Pollard rho + Miller-Rabin.
// Deterministic for uint64.
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <vector>
#include <algorithm>
#include <random>
#include <chrono>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

namespace {

uint64_t gcd_u64(uint64_t a, uint64_t b) {
    while (b) { uint64_t t = b; b = a % b; a = t; }
    return a;
}

uint64_t mulmod(uint64_t a, uint64_t b, uint64_t m) {
    return (unsigned __int128)a * b % m;
}

uint64_t addmod(uint64_t a, uint64_t b, uint64_t m) {
    return (a + b) % m;
}

// Pollard's rho with Brent's improvement.
uint64_t pollard_rho(uint64_t n) {
    if (n % 2 == 0) return 2;
    if (n % 3 == 0) return 3;

    // Random-ish initial values
    std::mt19937_64 rng(
        std::chrono::steady_clock::now().time_since_epoch().count() ^ n);

    while (true) {
        uint64_t c = 1 + rng() % (n - 2);
        uint64_t x = 2 + rng() % (n - 3);
        uint64_t y = x;
        uint64_t d = 1;

        auto f = [&](uint64_t v) { return addmod(mulmod(v, v, n), c, n); };

        while (d == 1) {
            x = f(x);
            y = f(f(y));
            uint64_t diff = x > y ? x - y : y - x;
            d = gcd_u64(diff, n);
        }
        if (d != n) return d;
        // Else retry with different c
    }
}

void factorize_recursive(uint64_t n, std::vector<uint64_t>& out) {
    if (n == 1) return;
    if (voss_is_prime_mr(n)) {
        out.push_back(n);
        return;
    }
    // Try small factors first
    for (uint64_t p : {2ULL, 3ULL, 5ULL, 7ULL, 11ULL, 13ULL, 17ULL, 19ULL, 23ULL, 29ULL, 31ULL, 37ULL}) {
        if (n % p == 0) {
            out.push_back(p);
            factorize_recursive(n / p, out);
            return;
        }
    }
    uint64_t d = pollard_rho(n);
    factorize_recursive(d, out);
    factorize_recursive(n / d, out);
}

} // anonymous namespace

extern "C" int voss_primes_factorize(uint64_t x,
                                     uint64_t** out_array,
                                     uint64_t* out_count) {
    if (out_array == nullptr || out_count == nullptr) {
        voss_set_last_error("out pointers are null");
        return VOSS_ERR_INVALID_ARG;
    }
    *out_array = nullptr;
    *out_count = 0;

    if (x < 2) {
        voss_set_last_error("x must be >= 2");
        return VOSS_ERR_INVALID_N;
    }

    try {
        std::vector<uint64_t> factors;

        // Trial division by small primes first
        static const uint64_t small_primes[] = {
            2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
            53, 59, 61, 67, 71, 73, 79, 83, 89, 97
        };
        uint64_t n = x;
        for (uint64_t p : small_primes) {
            if (p * p > n) break;
            while (n % p == 0) {
                factors.push_back(p);
                n /= p;
            }
        }
        if (n > 1) {
            factorize_recursive(n, factors);
        }
        std::sort(factors.begin(), factors.end());

        if (factors.empty()) {
            return VOSS_OK;  // *out_array stays NULL
        }

        uint64_t* arr = (uint64_t*)malloc(factors.size() * sizeof(uint64_t));
        if (arr == nullptr) {
            voss_set_last_error("host malloc failed");
            return VOSS_ERR_OUT_OF_MEMORY;
        }
        std::copy(factors.begin(), factors.end(), arr);

        *out_array = arr;
        *out_count = (uint64_t)factors.size();
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_INTERNAL;
    } catch (...) {
        voss_set_last_error("Unknown error");
        return VOSS_ERR_INTERNAL;
    }
}
