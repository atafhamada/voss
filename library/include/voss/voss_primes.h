#ifndef VOSS_PRIMES_H
#define VOSS_PRIMES_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// voss_primes_prime_count
//   Compute pi(N): number of primes <= N.
//
// Parameters:
//   N    - upper bound (must be >= 2)
//   out  - output pointer, receives pi(N)
//
// Returns:
//   VOSS_OK on success, or a VOSS_ERR_* code on failure.
//   On failure, out is not modified.
// ============================================================
int voss_primes_prime_count(uint64_t N, uint64_t* out);

#ifdef __cplusplus
}
#endif

#endif // VOSS_PRIMES_H
