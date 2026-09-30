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

#ifdef __cplusplus
}
#endif

#endif // VOSS_PRIMES_H
