// ============================================================
// test_prime_count.cpp — M0 integration test
// Verifies voss_primes_prime_count against known values (OEIS A006880)
// ============================================================

#include <cstdio>
#include <cstdint>
#include "voss/voss.h"
#include "voss/voss_primes.h"

static int failures = 0;

static void expect_eq_u64(const char* name, uint64_t got, uint64_t want) {
    if (got == want) {
        std::printf("  [OK]   %-40s %llu\n", name, (unsigned long long)got);
    } else {
        std::printf("  [FAIL] %-40s got=%llu want=%llu\n",
                    name, (unsigned long long)got, (unsigned long long)want);
        ++failures;
    }
}

static void expect_eq_int(const char* name, int got, int want) {
    if (got == want) {
        std::printf("  [OK]   %-40s %d\n", name, got);
    } else {
        std::printf("  [FAIL] %-40s got=%d want=%d\n", name, got, want);
        ++failures;
    }
}

static uint64_t call_count(uint64_t N, int* rc_out) {
    uint64_t out = 0;
    int rc = voss_primes_prime_count(N, &out);
    if (rc_out) *rc_out = rc;
    return out;
}

int main() {
    std::printf("=== VOSS M0 test: voss_primes_prime_count ===\n\n");

    // --- Error handling ---
    std::printf("Error handling:\n");
    expect_eq_int("voss_strerror(VOSS_OK)", 
                  (int)(voss_strerror(VOSS_OK)[0]), (int)('O'));
    {
        uint64_t out = 999;
        int rc = voss_primes_prime_count(0, &out);
        expect_eq_int("prime_count(0) returns INVALID_N", rc, VOSS_ERR_INVALID_N);
        expect_eq_u64("prime_count(0) leaves out untouched", out, 999);
    }
    {
        int rc = voss_primes_prime_count(10, nullptr);
        expect_eq_int("prime_count(10, NULL) returns INVALID_ARG", rc, VOSS_ERR_INVALID_ARG);
    }

    // --- Small values (verified by hand) ---
    std::printf("\nSmall values (hand-verified):\n");
    {
        int rc;
        expect_eq_u64("pi(2)",   call_count(2,   &rc), 1);
        expect_eq_u64("pi(3)",   call_count(3,   &rc), 2);
        expect_eq_u64("pi(5)",   call_count(5,   &rc), 3);
        expect_eq_u64("pi(10)",  call_count(10,  &rc), 4);
        expect_eq_u64("pi(100)", call_count(100, &rc), 25);
    }

    // --- Medium values (OEIS A006880 / known references) ---
    std::printf("\nMedium values (OEIS A006880):\n");
    {
        int rc;
        expect_eq_u64("pi(10^6)", call_count(1000000ULL,   &rc), 78498ULL);
        expect_eq_u64("pi(10^7)", call_count(10000000ULL,  &rc), 664579ULL);
        expect_eq_u64("pi(10^8)", call_count(100000000ULL, &rc), 5761455ULL);
    }

    std::printf("\n");
    if (failures == 0) {
        std::printf("ALL TESTS PASSED\n");
        return 0;
    } else {
        std::printf("%d TEST(S) FAILED\n", failures);
        std::printf("last error: %s\n", voss_get_last_error());
        return 1;
    }
}
