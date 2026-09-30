// ============================================================
// csv.cpp — CSV export for primes context (M4 part 5)
// ============================================================

#include <cstdio>
#include <cstdint>
#include <string>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"

// Internal accessors (defined in context.cu) — forward declare them here
// to avoid exposing them in the public header. Actually, we will use the
// public C API instead, so no forward declaration needed.

extern "C" int voss_primes_ctx_export_csv(voss_primes_ctx* ctx,
                                          const char* prefix) {
    if (ctx == nullptr) {
        voss_set_last_error("ctx is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (prefix == nullptr) {
        voss_set_last_error("prefix is null");
        return VOSS_ERR_INVALID_ARG;
    }

    std::string p(prefix);

    // === 1. Histogram CSV ===
    // We only have public access to twins/cousin/sexy. For the full histogram
    // we need more. Let's expose a minimal histogram iteration from context.cu.
    // For now, we use the statistics + the 3 gap counts we have.
    // Actually — we DO have access to the histogram via statistics.total_gaps.
    // But full histogram requires per-gap access, which we haven't exposed.
    //
    // For M4 part 5 (initial CSV export), export what we have:
    // chebyshev + large gaps + a small "summary" CSV.

    // === Chebyshev CSV ===
    {
        uint64_t pi_4_1 = 0, pi_4_3 = 0;
        int rc = voss_primes_ctx_chebyshev_bias(ctx, &pi_4_1, &pi_4_3);
        if (rc != VOSS_OK) {
            return rc;
        }

        std::string path = p + "_chebyshev.csv";
        FILE* fp = fopen(path.c_str(), "w");
        if (!fp) {
            voss_set_last_error("failed to open " + path);
            return VOSS_ERR_INTERNAL;
        }
        fprintf(fp, "pi_4_1,pi_4_3,difference\n");
        fprintf(fp, "%llu,%llu,%lld\n",
                (unsigned long long)pi_4_1,
                (unsigned long long)pi_4_3,
                (long long)pi_4_3 - (long long)pi_4_1);
        fclose(fp);
    }

    // === Large gaps CSV ===
    {
        uint64_t count = 0;
        int rc = voss_primes_ctx_large_gaps_count(ctx, &count);
        if (rc != VOSS_OK) {
            return rc;
        }

        std::string path = p + "_large_gaps.csv";
        FILE* fp = fopen(path.c_str(), "w");
        if (!fp) {
            voss_set_last_error("failed to open " + path);
            return VOSS_ERR_INTERNAL;
        }
        fprintf(fp, "position,gap\n");
        for (uint64_t i = 0; i < count; i++) {
            uint64_t pos = 0;
            uint32_t gap = 0;
            int rc2 = voss_primes_ctx_large_gaps_get(ctx, i, &pos, &gap);
            if (rc2 != VOSS_OK) {
                fclose(fp);
                return rc2;
            }
            fprintf(fp, "%llu,%u\n",
                    (unsigned long long)pos, (unsigned)gap);
        }
        fclose(fp);
    }

    // === Statistics summary CSV ===
    {
        voss_primes_stats_t s;
        int rc = voss_primes_ctx_statistics(ctx, &s);
        if (rc != VOSS_OK) {
            return rc;
        }

        std::string path = p + "_stats.csv";
        FILE* fp = fopen(path.c_str(), "w");
        if (!fp) {
            voss_set_last_error("failed to open " + path);
            return VOSS_ERR_INTERNAL;
        }
        fprintf(fp, "metric,value\n");
        fprintf(fp, "mean_gap,%.6f\n", s.mean_gap);
        fprintf(fp, "std_dev,%.6f\n", s.std_dev);
        fprintf(fp, "skewness,%.6f\n", s.skewness);
        fprintf(fp, "kurtosis,%.6f\n", s.kurtosis);
        fprintf(fp, "total_gaps,%llu\n", (unsigned long long)s.total_gaps);
        fclose(fp);
    }

    return VOSS_OK;
}
