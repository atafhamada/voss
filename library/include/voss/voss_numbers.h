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

// Divisor count: number of positive divisors of n.
// Conventions: tau(1) = 1. Domain: n >= 1.
int voss_numbers_tau(uint64_t n, uint64_t* out);

// Divisor sum: sum of positive divisors of n.
// Conventions: sigma(1) = 1. Domain: n >= 1.
int voss_numbers_sigma(uint64_t n, uint64_t* out);

// Moebius function: 1 if n has an even number of distinct prime
// factors (squarefree), -1 for odd, 0 if not squarefree.
// Convention: mu(1) = 1. Domain: n >= 1.
// Note: int* because the range is {-1, 0, 1}.
int voss_numbers_mu(uint64_t n, int* out);

// Greatest common divisor. Convention: gcd(0,0)=0, gcd(a,0)=a.
int voss_numbers_gcd(uint64_t a, uint64_t b, uint64_t* out);

// Least common multiple. Convention: lcm(0,k)=lcm(k,0)=0.
// Returns VOSS_ERR_OUT_OF_RANGE on uint64 overflow.
int voss_numbers_lcm(uint64_t a, uint64_t b, uint64_t* out);

// Fibonacci F(n). F(0)=0, F(1)=1. Fast doubling, O(log n).
// Domain: n <= 93 (F(94) overflows uint64).
int voss_numbers_fibonacci(uint64_t n, uint64_t* out);

// Factorial n!. 0! = 1. Iterative, O(n).
// Domain: n <= 20 (21! overflows uint64).
int voss_numbers_factorial(uint64_t n, uint64_t* out);

#ifdef __cplusplus
}
#endif

#endif // VOSS_NUMBERS_H
