#ifndef VOSS_PRIMES_H
#define VOSS_PRIMES_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// Direct function (M0)
// ============================================================
int voss_primes_prime_count(uint64_t N, uint64_t* out);

// ============================================================
// Profiles (M1)
// ============================================================
#define VOSS_PROFILE_MINIMAL   0
#define VOSS_PROFILE_STANDARD  1
#define VOSS_PROFILE_FULL      2

// ============================================================
// Handle (M1)
// ============================================================
typedef struct voss_primes_ctx voss_primes_ctx;

int voss_primes_ctx_new(uint64_t N, int profile, voss_primes_ctx** out_ctx);
void voss_primes_ctx_free(voss_primes_ctx* ctx);

// === Queries ===
int voss_primes_ctx_prime_count(voss_primes_ctx* ctx, uint64_t* out);
int voss_primes_ctx_twins(voss_primes_ctx* ctx, uint64_t* out);   // gap == 2
int voss_primes_ctx_cousin(voss_primes_ctx* ctx, uint64_t* out);  // gap == 4
int voss_primes_ctx_sexy(voss_primes_ctx* ctx, uint64_t* out);    // gap == 6

// ============================================================
// Sophie Germain primes (M5.1)
// ============================================================
// Count p <= N such that both p and 2*p+1 are prime.
// Requires STANDARD or FULL profile.
int voss_primes_ctx_sophie_germain(voss_primes_ctx* ctx, uint64_t* out);
// GPU variant: N up to 10^9. Same semantics: writes count to *out
// and caches in ctx->cached_sophie. Requires STANDARD or FULL profile.
int voss_primes_ctx_sophie_germain_upto(voss_primes_ctx* ctx, uint64_t* out);

// ============================================================
// Statistics (M4)
// ============================================================
typedef struct {
    double   mean_gap;     // mean gap value
    double   std_dev;      // standard deviation
    double   skewness;     // 3rd standardized moment
    double   kurtosis;     // excess kurtosis (4th moment - 3)
    uint64_t total_gaps;   // sum of all gap counts
} voss_primes_stats_t;

// Compute gap statistics. Requires STANDARD or FULL profile.
// Returns VOSS_ERR_INVALID_ARG if profile is MINIMAL.
int voss_primes_ctx_statistics(voss_primes_ctx* ctx, voss_primes_stats_t* out);

// ============================================================
// Chebyshev bias (M4)
// ============================================================
// Count primes <= N that are 1 or 3 (mod 4).
// Requires STANDARD or FULL profile.
int voss_primes_ctx_chebyshev_bias(voss_primes_ctx* ctx,
                                   uint64_t* out_pi_4_1,
                                   uint64_t* out_pi_4_3);

// ============================================================
// Large gaps (M4) — gaps >= 500
// ============================================================
// Get number of large gaps (>= 500) found. Requires STANDARD or FULL.
int voss_primes_ctx_large_gaps_count(voss_primes_ctx* ctx, uint64_t* out_count);

// Get the i-th large gap (sorted descending by gap size).
// Position is the second prime of the gap; gap is the size.
int voss_primes_ctx_large_gaps_get(voss_primes_ctx* ctx, uint64_t index,
                                   uint64_t* out_position, uint32_t* out_gap);

// ============================================================
// CSV export (M4 part 5)
// ============================================================
// Export the computed results to CSV files with the given prefix.
// Writes:
//   <prefix>_chebyshev.csv   (pi_4_1, pi_4_3, difference)
//   <prefix>_large_gaps.csv  (position, gap)
//   <prefix>_stats.csv       (mean_gap, std_dev, ...)
//
// Returns VOSS_ERR_INVALID_ARG if profile is MINIMAL.
// Returns VOSS_ERR_INTERNAL if file I/O fails.
int voss_primes_ctx_export_csv(voss_primes_ctx* ctx, const char* prefix);

// ============================================================
// Direct functions (M3) — no handle needed
// ============================================================

// Primes in range [a, b] — default limit 10^9
// Returns a malloc'd array in *out_array (freed by voss_free) and count in *out_count.
// If count > default limit, returns VOSS_ERR_OUT_OF_RANGE.
int voss_primes_in_range(uint64_t a, uint64_t b,
                         uint64_t** out_array, uint64_t* out_count);

// Primes in range [a, b] — custom limit on count
int voss_primes_in_range_with_limit(uint64_t a, uint64_t b, uint64_t max_count,
                                    uint64_t** out_array, uint64_t* out_count);

// nth prime (1-indexed): n=1 returns 2, n=2 returns 3, ...
int voss_primes_nth(uint64_t n, uint64_t* out_prime);

// Smallest prime > x
int voss_primes_next(uint64_t x, uint64_t* out_prime);

// Largest prime < x
int voss_primes_prev(uint64_t x, uint64_t* out_prime);

// ============================================================
// Primality (M5.1)
// ============================================================
// Test if x is prime (deterministic Miller-Rabin).
// Result written to *out: 1 = prime, 0 = not prime.
int voss_primes_is_prime(uint64_t x, int* out);

// ============================================================
// Factorization (M5.2)
// ============================================================
// Factorize x into its prime factors (with multiplicity), sorted ascending.
// Returns a malloc'd array in *out_array (freed by voss_free) and count.
// x must be >= 2.
int voss_primes_factorize(uint64_t x,
                          uint64_t** out_array,
                          uint64_t* out_count);

// ============================================================
// Mersenne + Fermat primes (M5.3)
// ============================================================
// Test whether M_p = 2^p - 1 is prime (Lucas-Lehmer).
// p must be in [2, 63].
int voss_primes_is_mersenne_prime(uint32_t p, int* out);

// Test whether F_n = 2^(2^n) + 1 is prime.
// n must be in [0, 5].
int voss_primes_is_fermat_prime(uint32_t n, int* out);

// ============================================================
// Progress callback (M6, v0.7.0)
// ============================================================
// Called after each internal segment during Context computation.
typedef void (*voss_progress_cb)(int seg, int total,
                                 uint64_t primes_in_seg,
                                 uint64_t cumulative,
                                 void* user);

int voss_primes_ctx_set_progress(voss_primes_ctx* ctx,
                                 voss_progress_cb cb,
                                 void* user);

// ============================================================
// Goldbach partitions (M5.4)
// ============================================================
// Count pairs (p1, p2) with p1 <= p2 both prime and p1 + p2 == n.
// n must be even and >= 4.
int voss_primes_goldbach_count(uint64_t n, uint64_t* out);

// Return all Goldbach partitions as a flat array [p1_0, p2_0, p1_1, p2_1, ...].
// out_count receives the number of pairs (not the array length).
// Array is malloc'd, freed by voss_free.
int voss_primes_goldbach_partitions(uint64_t n,
                                   uint64_t** out_array,
                                   uint64_t* out_count);

// ============================================================
// Goldbach empirical test up to N (M6, GPU)
// ============================================================
// Test Goldbach's conjecture for all even n in [4, N] on GPU.
// Returns the first max_ce counterexamples (n with no Goldbach pair).
// Array is malloc'd, freed by voss_free.
int voss_primes_goldbach_test_upto(uint64_t N,
                                   uint64_t** out_counterexamples,
                                   uint64_t* out_count,
                                   uint64_t max_counterexamples);

#ifdef __cplusplus
}
#endif

#endif // VOSS_PRIMES_H
