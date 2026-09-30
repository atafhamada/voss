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

#ifdef __cplusplus
}
#endif

#endif // VOSS_PRIMES_H
