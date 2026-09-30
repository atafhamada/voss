// ============================================================
// sanitizer_test.cpp — Exercise all kernels under compute-sanitizer
// ============================================================

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include "voss/voss.h"
#include "voss/voss_primes.h"

static int failures = 0;

#define CHECK(cond, msg) do { \
    if (!(cond)) { std::printf("  [FAIL] %s\n", msg); failures++; } \
    else         { std::printf("  [OK]   %s\n", msg); } \
} while (0)

int main() {
    std::printf("=== Full Context pipeline under compute-sanitizer ===\n\n");

    // Use N = 10^6: small enough to run fast under sanitizer,
    // large enough to exercise all kernels (multi-launch, sort, gaps, mod4).
    const uint64_t N = 1000000ULL;

    voss_primes_ctx* ctx = nullptr;
    int rc = voss_primes_ctx_new(N, VOSS_PROFILE_STANDARD, &ctx);
    CHECK(rc == VOSS_OK, "ctx_new");

    // Prime count
    uint64_t pi = 0;
    rc = voss_primes_ctx_prime_count(ctx, &pi);
    CHECK(rc == VOSS_OK && pi == 78498ULL, "prime_count(10^6)");

    // Twins
    uint64_t tw = 0;
    rc = voss_primes_ctx_twins(ctx, &tw);
    CHECK(rc == VOSS_OK && tw == 8169ULL, "twins(10^6)");

    // Cousin
    uint64_t co = 0;
    rc = voss_primes_ctx_cousin(ctx, &co);
    CHECK(rc == VOSS_OK && co == 8143ULL, "cousin(10^6)");

    // Sexy
    uint64_t sx = 0;
    rc = voss_primes_ctx_sexy(ctx, &sx);
    CHECK(rc == VOSS_OK && sx == 13549ULL, "sexy(10^6)");

    // Statistics
    voss_primes_stats_t stats;
    rc = voss_primes_ctx_statistics(ctx, &stats);
    CHECK(rc == VOSS_OK && stats.total_gaps == 78497ULL, "statistics(10^6)");

    // Chebyshev
    uint64_t c1 = 0, c3 = 0;
    rc = voss_primes_ctx_chebyshev_bias(ctx, &c1, &c3);
    CHECK(rc == VOSS_OK && (c1 + c3 + 1 == pi), "chebyshev(10^6)");

    // Large gaps (expected 0 at 10^6)
    uint64_t lg_count = 0;
    rc = voss_primes_ctx_large_gaps_count(ctx, &lg_count);
    CHECK(rc == VOSS_OK && lg_count == 0, "large_gaps_count(10^6)");

    // CSV export
    rc = voss_primes_ctx_export_csv(ctx, "/tmp/voss_sanitizer_test");
    CHECK(rc == VOSS_OK, "export_csv(10^6)");

    voss_primes_ctx_free(ctx);

    // Also test M3 direct functions (range/nth/next/prev)
    uint64_t* arr = nullptr;
    uint64_t count = 0;
    rc = voss_primes_in_range(10, 100, &arr, &count);
    CHECK(rc == VOSS_OK && count == 21, "in_range(10,100)");
    if (arr) voss_free(arr);

    uint64_t p = 0;
    rc = voss_primes_nth(100, &p);
    CHECK(rc == VOSS_OK && p == 541, "nth(100)");

    rc = voss_primes_next(1000, &p);
    CHECK(rc == VOSS_OK && p == 1009, "next_prime(1000)");

    rc = voss_primes_prev(1000, &p);
    CHECK(rc == VOSS_OK && p == 997, "prev_prime(1000)");

    std::printf("\n");
    if (failures == 0) {
        std::printf("ALL CHECKS PASSED\n");
        return 0;
    } else {
        std::printf("%d CHECK(S) FAILED\n", failures);
        return 1;
    }
}
