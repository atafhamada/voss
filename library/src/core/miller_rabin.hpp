#ifndef VOSS_MILLER_RABIN_HPP
#define VOSS_MILLER_RABIN_HPP

#include <cstdint>

// Deterministic Miller-Rabin for all 64-bit integers.
// Witnesses: 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37
// (sufficient for all n < 2^64).
bool voss_is_prime_mr(uint64_t n);

#endif // VOSS_MILLER_RABIN_HPP
