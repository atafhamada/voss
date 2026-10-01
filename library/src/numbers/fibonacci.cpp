// ============================================================
// fibonacci.cpp — voss_numbers_fibonacci (M6.2c)
//
// Fast doubling: O(log n).
//   F(2k)   = F(k) * (2*F(k+1) - F(k))
//   F(2k+1) = F(k)^2 + F(k+1)^2
// Domain: n <= 93 (F(93) = 12200160415121876738 fits uint64;
//         F(94) overflows).
// unsigned __int128 used internally; F(93)^2 ~ 1.49e38 fits.
// ============================================================

#include <cstdint>
#include <utility>

#include "voss/voss.h"
#include "voss/voss_numbers.h"
#include "core/internal.hpp"

namespace {

// returns (F(n), F(n+1))
std::pair<uint64_t, uint64_t> fib_pair(uint64_t n) {
    if (n == 0) return {0, 1};
    auto half = fib_pair(n >> 1);
    uint64_t a = half.first;    // F(k)
    uint64_t b = half.second;   // F(k+1)
    unsigned __int128 c = (unsigned __int128)a *
                          ((unsigned __int128)2 * b - a);        // F(2k)
    unsigned __int128 d = (unsigned __int128)a * a +
                          (unsigned __int128)b * b;              // F(2k+1)
    if (n & 1) return {(uint64_t)d, (uint64_t)(c + d)};
    return {(uint64_t)c, (uint64_t)d};
}

}  // namespace

extern "C" int voss_numbers_fibonacci(uint64_t n, uint64_t* out) {
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (n > 93) {
        voss_set_last_error("fibonacci(n) overflows uint64 for n >= 94");
        return VOSS_ERR_OUT_OF_RANGE;
    }
    *out = fib_pair(n).first;
    return VOSS_OK;
}
