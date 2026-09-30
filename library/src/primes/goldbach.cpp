// ============================================================
// goldbach.cpp — Goldbach partitions (M5.4)
//
// For an even n >= 4, count pairs (p1, p2) with p1 <= p2 both prime
// and p1 + p2 == n.
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <vector>
#include <algorithm>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

namespace {

// Collect all Goldbach partitions of an even n >= 4.
std::vector<std::pair<uint64_t,uint64_t>> goldbach_partitions(uint64_t n) {
    std::vector<std::pair<uint64_t,uint64_t>> result;
    if (n < 4 || n % 2 != 0) return result;

    // Iterate p1 from 2 up to n/2, check if n - p1 is prime.
    // For p1 = 2, n-2: if n even, n-2 is even (unless n-2 == 2).
    // Skip p1 = 2 unless n = 4.
    if (n == 4) {
        result.emplace_back(2, 2);
        return result;
    }

    // p1 must be odd for n > 4 (since n-2 would be even)
    // Start from 3, step 2.
    for (uint64_t p1 = 3; p1 <= n / 2; p1 += 2) {
        if (!voss_is_prime_mr(p1)) continue;
        uint64_t p2 = n - p1;
        if (voss_is_prime_mr(p2)) {
            result.emplace_back(p1, p2);
        }
    }
    return result;
}

} // anonymous namespace

extern "C" int voss_primes_goldbach_count(uint64_t n, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n < 4 || n % 2 != 0) {
        voss_set_last_error("n must be even and >= 4");
        return VOSS_ERR_INVALID_N;
    }
    if (n > 100000000ULL) {  // 10^8 (CPU limit)
        voss_set_last_error("n exceeds maximum (10^8, CPU-only for now)");
        return VOSS_ERR_OUT_OF_RANGE;
    }

    try {
        auto parts = goldbach_partitions(n);
        *out = (uint64_t)parts.size();
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_INTERNAL;
    }
}

extern "C" int voss_primes_goldbach_partitions(uint64_t n,
                                              uint64_t** out_array,
                                              uint64_t* out_count) {
    if (out_array == nullptr || out_count == nullptr) {
        voss_set_last_error("out pointers are null");
        return VOSS_ERR_INVALID_ARG;
    }
    *out_array = nullptr;
    *out_count = 0;

    if (n < 4 || n % 2 != 0) {
        voss_set_last_error("n must be even and >= 4");
        return VOSS_ERR_INVALID_N;
    }
    if (n > 100000000ULL) {
        voss_set_last_error("n exceeds maximum (10^8, CPU-only for now)");
        return VOSS_ERR_OUT_OF_RANGE;
    }

    try {
        auto parts = goldbach_partitions(n);
        if (parts.empty()) {
            return VOSS_OK;  // *out_array stays NULL
        }

        // Store as [p1_0, p2_0, p1_1, p2_1, ...]
        uint64_t* arr = (uint64_t*)malloc(parts.size() * 2 * sizeof(uint64_t));
        if (arr == nullptr) {
            voss_set_last_error("host malloc failed");
            return VOSS_ERR_OUT_OF_MEMORY;
        }
        for (size_t i = 0; i < parts.size(); i++) {
            arr[2*i]     = parts[i].first;
            arr[2*i + 1] = parts[i].second;
        }

        *out_array = arr;
        *out_count = (uint64_t)parts.size();
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_INTERNAL;
    }
}
