#ifndef VOSS_NUMBERS_H
#define VOSS_NUMBERS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// Numbers section (M6.2a) — arithmetic functions (CPU)
// ============================================================

// Euler's totient: count of 1 <= k <= n with gcd(k, n) == 1.
// Convention: phi(1) = 1. Domain: n >= 1.
int voss_numbers_phi(uint64_t n, uint64_t* out);

#ifdef __cplusplus
}
#endif

#endif // VOSS_NUMBERS_H
