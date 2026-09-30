// ============================================================
// context.cu — voss_primes_ctx implementation (M1 + M2)
//
// M1: handle + lazy prime_count cache + profiles
// M2: gap histogram + twins/cousin/sexy queries
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <string>
#include <stdexcept>
#include <vector>
#include <cuda_runtime.h>
#include <thrust/sort.h>
#include <thrust/device_ptr.h>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"
#include "core/miller_rabin.hpp"

// === Public kernel forward declarations ===
__global__ void sieve_w30_seg_kernel(
    uint32_t* __restrict__ bits,
    uint32_t p,
    int64_t s0, int64_t s1, int64_t s2, int64_t s3,
    int64_t s4, int64_t s5, int64_t s6, int64_t s7,
    int64_t seg_bits);

__global__ void extract_w30_seg_kernel(
    const uint32_t* __restrict__ bits,
    int64_t num_words,
    int64_t seg_bits,
    uint64_t* __restrict__ positions,
    uint64_t* __restrict__ global_count);

// === Gap kernel (defined in gaps.cu) ===
struct LargeGap {
    uint64_t position;
    int32_t  gap;
    int32_t  _pad;
};

__global__ void gaps_w30_seg_kernel(
    const uint64_t* __restrict__ positions,
    uint64_t n,
    uint64_t k_base,
    int64_t* __restrict__ global_hist,
    LargeGap* __restrict__ large_gaps,
    unsigned int* __restrict__ large_gap_count,
    int large_gap_threshold,
    int max_large_gaps);

__global__ void mod4_count_kernel(
    const uint64_t* __restrict__ positions,
    uint64_t n,
    uint64_t k_base,
    unsigned long long* __restrict__ cnt1,
    unsigned long long* __restrict__ cnt3);

// === M2/M4 constants ===
#define VOSS_MAX_GAP 100000
#define VOSS_LARGE_GAP_THRESHOLD 500
#define VOSS_MAX_LARGE_GAPS 2000000

// ============================================================
// Handle struct (opaque)
// ============================================================
struct voss_primes_ctx {
    uint64_t N = 0;
    int profile = VOSS_PROFILE_STANDARD;

    // Lazy cache: prime count
    uint64_t cached_prime_count = 0;
    bool     has_prime_count = false;

    // Lazy cache: gap histogram (size VOSS_MAX_GAP)
    std::vector<int64_t> cached_histogram;
    bool has_histogram = false;

    // Lazy cache: Chebyshev bias counts
    uint64_t cached_class1 = 0;   // primes === 1 (mod 4), includes 5
    uint64_t cached_class3 = 0;   // primes === 3 (mod 4), includes 3
    bool has_chebyshev = false;

    // Lazy cache: large gaps (>= VOSS_LARGE_GAP_THRESHOLD)
    std::vector<LargeGap> cached_large_gaps;
    bool has_large_gaps = false;

    // Lazy cache: Sophie Germain count
    uint64_t cached_sophie = 0;
    bool has_sophie = false;
};

// ============================================================
// Internal helpers
// ============================================================
namespace {

const int W30[8] = {1, 7, 11, 13, 17, 19, 23, 29};

void generate_base_primes(int limit, uint32_t** out, int* count) {
    bool* sieve = (bool*)malloc(limit + 1);
    for (int i = 0; i <= limit; i++) sieve[i] = true;
    sieve[0] = sieve[1] = false;
    for (int i = 2; (long long)i * i <= limit; i++)
        if (sieve[i])
            for (int j = i * i; j <= limit; j += i) sieve[j] = false;
    int cnt = 0;
    for (int i = 7; i <= limit; i++) if (sieve[i]) cnt++;
    uint32_t* arr = (uint32_t*)malloc(cnt * sizeof(uint32_t));
    int idx = 0;
    for (int i = 7; i <= limit; i++) if (sieve[i]) arr[idx++] = i;
    free(sieve);
    *out = arr; *count = cnt;
}

int64_t modinv(int64_t a, int64_t m) {
    int64_t t = 0, newt = 1, r = m, newr = a % m;
    while (newr != 0) {
        int64_t q = r / newr;
        int64_t tmp = newt; newt = t - q * newt; t = tmp;
        tmp = newr; newr = r - q * newr; r = tmp;
    }
    if (t < 0) t += m;
    return t;
}

struct LaunchInfo {
    uint32_t p;
    int64_t s[8];
    int grid_x;
};

struct DeviceBuffer {
    void* ptr = nullptr;
    explicit DeviceBuffer(size_t bytes) {
        cudaError_t err = cudaMalloc(&ptr, bytes);
        if (err != cudaSuccess) {
            throw std::runtime_error(
                std::string("cudaMalloc failed: ") + cudaGetErrorString(err));
        }
    }
    ~DeviceBuffer() { if (ptr) cudaFree(ptr); }
    DeviceBuffer(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;
    uint32_t* as_u32() const { return static_cast<uint32_t*>(ptr); }
    uint64_t* as_u64() const { return static_cast<uint64_t*>(ptr); }
    int64_t*  as_i64() const { return static_cast<int64_t*>(ptr);  }
    LargeGap* as_lg()  const { return static_cast<LargeGap*>(ptr); }
    unsigned int* as_u32i() const { return static_cast<unsigned int*>(ptr); }
};

struct CudaStream {
    cudaStream_t s = nullptr;
    CudaStream() {
        cudaError_t err = cudaStreamCreate(&s);
        if (err != cudaSuccess) {
            throw std::runtime_error(
                std::string("cudaStreamCreate failed: ") + cudaGetErrorString(err));
        }
    }
    ~CudaStream() { if (s) cudaStreamDestroy(s); }
    CudaStream(const CudaStream&) = delete;
    CudaStream& operator=(const CudaStream&) = delete;
};

struct BasePrimes {
    uint32_t* arr = nullptr;
    int count = 0;
    explicit BasePrimes(int limit) { generate_base_primes(limit, &arr, &count); }
    ~BasePrimes() { if (arr) free(arr); }
    BasePrimes(const BasePrimes&) = delete;
    BasePrimes& operator=(const BasePrimes&) = delete;
};

struct CudaGraph {
    cudaGraph_t graph = nullptr;
    cudaGraphExec_t exec = nullptr;
    ~CudaGraph() {
        if (exec) cudaGraphExecDestroy(exec);
        if (graph) cudaGraphDestroy(graph);
    }
};

inline void check_cuda(cudaError_t err, const char* what) {
    if (err != cudaSuccess) {
        throw std::runtime_error(
            std::string(what) + " failed: " + cudaGetErrorString(err));
    }
}

// ============================================================
// Core: compute pi(N) and (optionally) gap histogram
//
// If compute_gaps is true, histogram is filled (size VOSS_MAX_GAP).
// Otherwise histogram remains untouched.
// ============================================================
struct FullResult {
    uint64_t prime_count;
    std::vector<int64_t> histogram;  // empty if compute_gaps == false
    uint64_t class1 = 0;             // Chebyshev: === 1 (mod 4)
    uint64_t class3 = 0;             // Chebyshev: === 3 (mod 4)
    std::vector<LargeGap> large_gaps; // empty if compute_gaps == false
};

FullResult compute_full_impl(uint64_t N, bool compute_gaps) {
    FullResult result;
    result.prime_count = 0;
    uint64_t class1_total = 0;
    uint64_t class3_total = 0;

    // Small N handled directly. Histogram must be sized correctly even if empty
    // to avoid out-of-bounds reads in get_gap_count.
    auto init_empty_histogram = [&]() {
        if (compute_gaps) {
            result.histogram.assign(VOSS_MAX_GAP, 0);
        }
    };

    if (N < 3) {
        result.prime_count = 1;
        init_empty_histogram();
        return result;  // no gaps (only prime 2)
    }
    if (N < 5) {
        result.prime_count = 2;
        init_empty_histogram();
        if (compute_gaps) result.histogram[1] = 1;  // gap 2 -> 3
        return result;
    }
    if (N < 7) {
        result.prime_count = 3;
        init_empty_histogram();
        if (compute_gaps) {
            result.histogram[1] = 1;  // gap 2 -> 3
            result.histogram[2] = 1;  // gap 3 -> 5
        }
        return result;
    }

    {
        int device_count = 0;
        check_cuda(cudaGetDeviceCount(&device_count), "cudaGetDeviceCount");
        if (device_count == 0) {
            throw std::runtime_error("No CUDA device available");
        }

        // Segment size chosen to fit within Colab A100 memory (~40 GB).
    // Positions + thrust temp must fit: see M4 fix.
    // Dynamic segment size: for small N, don't over-allocate.
    // Cap at 5e10 for Colab A100 memory (~40 GB usable).
    const int64_t MAX_SEG_NUM = 50000000010LL;
    int64_t SEG_NUM;
    if ((int64_t)N < MAX_SEG_NUM) {
        SEG_NUM = (((int64_t)N + 29) / 30) * 30 + 10;
    } else {
        SEG_NUM = MAX_SEG_NUM;
    }
        const int64_t SEG_K    = SEG_NUM / 30;
        const int64_t SEG_BITS = SEG_K * 8;
        const int64_t NUM_SEG  = (N + SEG_NUM - 1) / SEG_NUM;

        int limit = (int)std::sqrt((double)N) + 1;
        BasePrimes base(limit);

        // Per-segment buffer size (v7-golden pattern).
    // Each segment covers SEG_NUM = 10^11 numbers, containing at most
    // ~4.3 * 10^9 primes. Buffer is reused across segments.
    // Dynamic position buffer: ~SEG_NUM / ln(SEG_NUM) * 1.3 primes expected.
    // Cap at 2.2e9 (for the maximum 5e10 segment).
    double est = (double)SEG_NUM / std::log((double)SEG_NUM) * 1.3;
    int64_t max_pos = (int64_t)est + 1000;
    if (max_pos > 2200000000LL) max_pos = 2200000000LL;
    if (max_pos < 100) max_pos = 100;

        int64_t seg_words = (SEG_BITS + 31) / 32;
        size_t bits_bytes = (size_t)seg_words * sizeof(uint32_t);
        size_t pos_bytes  = (size_t)max_pos * sizeof(uint64_t);

        DeviceBuffer bits_buf(bits_bytes);
        DeviceBuffer pos_buf(pos_bytes);
        DeviceBuffer cnt_buf(sizeof(uint64_t));
        CudaStream stream;

        // Extra buffers only needed if computing gaps
        DeviceBuffer gaps_buf(compute_gaps ? (size_t)VOSS_MAX_GAP * sizeof(int64_t) : sizeof(int64_t));
        DeviceBuffer lg_buf(compute_gaps
            ? (size_t)VOSS_MAX_LARGE_GAPS * sizeof(LargeGap)
            : sizeof(LargeGap));
        DeviceBuffer lgcnt_buf(sizeof(unsigned int));

        // Mod-4 buffers (always needed if compute_gaps)
        DeviceBuffer mod4_1_buf(sizeof(unsigned long long));
        DeviceBuffer mod4_3_buf(sizeof(unsigned long long));

        uint32_t* bits_d = bits_buf.as_u32();
        uint64_t* positions_d = pos_buf.as_u64();
        uint64_t* count_d = cnt_buf.as_u64();
        int64_t*  gaps_d = gaps_buf.as_i64();
        LargeGap* large_gaps_d = lg_buf.as_lg();
        unsigned int* lg_cnt_d = lgcnt_buf.as_u32i();
        unsigned long long* mod4_1_d = static_cast<unsigned long long*>(mod4_1_buf.ptr);
        unsigned long long* mod4_3_d = static_cast<unsigned long long*>(mod4_3_buf.ptr);

        if (compute_gaps) {
            check_cuda(cudaMemset(gaps_d, 0, (size_t)VOSS_MAX_GAP * sizeof(int64_t)),
                       "cudaMemset(gaps)");
            // lg_cnt_d is NOT reset per segment — accumulates large gaps globally
            check_cuda(cudaMemset(lg_cnt_d, 0, sizeof(unsigned int)),
                       "cudaMemset(lg_cnt)");
        }

        uint64_t total = 3;
        uint64_t last_prime = 5;

        // Allocate histogram accumulator if needed
        if (compute_gaps) {
            result.histogram.assign(VOSS_MAX_GAP, 0);
        }

        const int BLOCK = 256;
        std::vector<LaunchInfo> launches;
        launches.reserve(base.count);

        // Temporary host buffer for per-segment gaps readback
        std::vector<int64_t> gaps_seg_buf;
        if (compute_gaps) gaps_seg_buf.resize(VOSS_MAX_GAP);

        for (int64_t seg = 0; seg < NUM_SEG; seg++) {
            int64_t seg_low_num  = seg * SEG_NUM + 1;
            int64_t seg_high_num = (seg + 1) * SEG_NUM;
            if (seg_high_num > (int64_t)N) seg_high_num = (int64_t)N;
            int64_t k_base = seg * SEG_K;

            int64_t seg_bits = SEG_BITS;
            if (seg == NUM_SEG - 1) {
                int64_t r_num = (int64_t)N - seg * SEG_NUM;
                int64_t r_k = r_num / 30;
                int64_t r_r = r_num % 30;
                seg_bits = r_k * 8;
                for (int i = 0; i < 8; i++)
                    if (W30[i] <= r_r) seg_bits++;
            }
            int64_t current_seg_words = (seg_bits + 31) / 32;

            launches.clear();
            for (int i = 0; i < base.count; i++) {
                uint32_t p = base.arr[i];
                int64_t p_sq = (int64_t)p * p;
                if (p_sq > seg_high_num) break;

                int64_t inv30 = modinv(30 % p, (int64_t)p);

                LaunchInfo L;
                L.p = p;
                int64_t max_steps = 0;
                for (int o = 0; o < 8; o++) {
                    int r = W30[o];
                    int64_t k0 = ((int64_t)((-r % (int)p + (int)p) % (int)p) * inv30) % (int64_t)p;
                    int64_t n = 30LL * k0 + r;
                    int64_t lower_bound = (p_sq > seg_low_num) ? p_sq : seg_low_num;
                    if (n < lower_bound) {
                        int64_t step_val = 30LL * (int64_t)p;
                        int64_t diff = lower_bound - n;
                        int64_t add = ((diff + step_val - 1) / step_val) * step_val;
                        n += add;
                    }
                    if (n > seg_high_num) { L.s[o] = -1; continue; }
                    int64_t k_val = (n - r) / 30;
                    int64_t local_idx = (k_val - k_base) * 8 + o;
                    if (local_idx < 0 || local_idx >= seg_bits) { L.s[o] = -1; continue; }
                    L.s[o] = local_idx;
                    int64_t steps = (seg_bits - 1 - local_idx) / (8 * (int64_t)p) + 1;
                    if (steps > max_steps) max_steps = steps;
                }
                if (max_steps <= 0) continue;
                int64_t total_threads = max_steps * 8;
                L.grid_x = (int)((total_threads + BLOCK - 1) / BLOCK);
                launches.push_back(L);
            }

            {
                CudaGraph g;
                check_cuda(cudaStreamBeginCapture(stream.s, cudaStreamCaptureModeGlobal),
                           "cudaStreamBeginCapture");
                for (auto& L : launches) {
                    sieve_w30_seg_kernel<<<L.grid_x, BLOCK, 0, stream.s>>>(
                        bits_d, L.p, L.s[0], L.s[1], L.s[2], L.s[3],
                        L.s[4], L.s[5], L.s[6], L.s[7], seg_bits);
                }
                check_cuda(cudaStreamEndCapture(stream.s, &g.graph),
                           "cudaStreamEndCapture");
                check_cuda(cudaGraphInstantiate(&g.exec, g.graph, NULL, NULL, 0),
                           "cudaGraphInstantiate");

                check_cuda(cudaMemset(bits_d, 0xFF, current_seg_words * sizeof(uint32_t)),
                           "cudaMemset(bits)");
                if (seg == 0) {
                    uint32_t fw = 0xFFFFFFFE;
                    check_cuda(cudaMemcpy(bits_d, &fw, 4, cudaMemcpyHostToDevice),
                               "cudaMemcpy(first word)");
                }

                check_cuda(cudaGraphLaunch(g.exec, stream.s), "cudaGraphLaunch");
                check_cuda(cudaStreamSynchronize(stream.s), "cudaStreamSynchronize(sieve)");
            }

            check_cuda(cudaMemset(count_d, 0, sizeof(uint64_t)), "cudaMemset(count)");

            int ext_grid = (int)((current_seg_words + BLOCK - 1) / BLOCK);
            extract_w30_seg_kernel<<<ext_grid, BLOCK>>>(
                bits_d, current_seg_words, seg_bits, positions_d, count_d);
            check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize(extract)");

            uint64_t n_pos = 0;
            check_cuda(cudaMemcpy(&n_pos, count_d, 8, cudaMemcpyDeviceToHost),
                       "cudaMemcpy(count->host)");

            if (n_pos > (uint64_t)max_pos) {
                throw std::runtime_error("Position buffer overflow (increase max_pos)");
            }

            total += n_pos;

            if (compute_gaps && n_pos > 0) {
                // Sort positions
                thrust::device_ptr<uint64_t> ptr(positions_d);
                thrust::sort(ptr, ptr + n_pos);
                check_cuda(cudaDeviceSynchronize(), "thrust::sort");

                // Mod-4 count (Chebyshev)
                check_cuda(cudaMemset(mod4_1_d, 0, sizeof(unsigned long long)),
                           "cudaMemset(mod4_1)");
                check_cuda(cudaMemset(mod4_3_d, 0, sizeof(unsigned long long)),
                           "cudaMemset(mod4_3)");
                int mod4_grid = (int)((n_pos + 256 - 1) / 256);
                mod4_count_kernel<<<mod4_grid, 256>>>(
                    positions_d, n_pos, k_base, mod4_1_d, mod4_3_d);
                check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize(mod4)");

                unsigned long long c1, c3;
                check_cuda(cudaMemcpy(&c1, mod4_1_d, sizeof(c1),
                                      cudaMemcpyDeviceToHost), "cudaMemcpy(mod4_1)");
                check_cuda(cudaMemcpy(&c3, mod4_3_d, sizeof(c3),
                                      cudaMemcpyDeviceToHost), "cudaMemcpy(mod4_3)");
                class1_total += c1;
                class3_total += c3;

                // First/last values in this segment
                uint64_t first_local_idx = 0, last_local_idx = 0;
                check_cuda(cudaMemcpy(&first_local_idx, positions_d, 8, cudaMemcpyDeviceToHost),
                           "cudaMemcpy(first_idx)");
                check_cuda(cudaMemcpy(&last_local_idx, positions_d + n_pos - 1, 8, cudaMemcpyDeviceToHost),
                           "cudaMemcpy(last_idx)");

                uint64_t first_val = 30ULL * (k_base + (first_local_idx >> 3)) + (uint64_t)W30[first_local_idx & 7];
                uint64_t last_val  = 30ULL * (k_base + (last_local_idx >> 3))  + (uint64_t)W30[last_local_idx & 7];

                // Boundary gap from previous segment
                if (seg > 0 || last_prime > 0) {
                    uint64_t d0 = first_val - last_prime;
                    if (d0 > 0 && d0 < VOSS_MAX_GAP) {
                        result.histogram[d0]++;
                    }
                }

                // Reset gaps_d, run kernel
                check_cuda(cudaMemset(gaps_d, 0, (size_t)VOSS_MAX_GAP * sizeof(int64_t)),
                           "cudaMemset(gaps per seg)");

                int gaps_grid = (int)((n_pos + 256 - 1) / 256);
                gaps_w30_seg_kernel<<<gaps_grid, 256>>>(
                    positions_d, n_pos, k_base,
                    gaps_d, large_gaps_d, lg_cnt_d,
                    VOSS_LARGE_GAP_THRESHOLD, VOSS_MAX_LARGE_GAPS);
                check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize(gaps)");

                // Read back and accumulate
                check_cuda(cudaMemcpy(gaps_seg_buf.data(), gaps_d,
                                      (size_t)VOSS_MAX_GAP * sizeof(int64_t),
                                      cudaMemcpyDeviceToHost),
                           "cudaMemcpy(gaps)");

                for (int i = 1; i < VOSS_MAX_GAP; i++) {
                    result.histogram[i] += gaps_seg_buf[i];
                }

                last_prime = last_val;
            } else if (n_pos > 0) {
                // Even without gaps, we still need last_prime updated for potential
                // future gaps computation across segments — but for M2 simple case
                // (single segment), this doesn't matter.
                uint64_t last_local_idx = 0;
                check_cuda(cudaMemcpy(&last_local_idx, positions_d + n_pos - 1, 8, cudaMemcpyDeviceToHost),
                           "cudaMemcpy(last_idx)");
                last_prime = 30ULL * (k_base + (last_local_idx >> 3)) + (uint64_t)W30[last_local_idx & 7];
            }
        }

        // Adjust: v7-golden adds +1 to histogram[1] and histogram[2]
        // to account for the primes 2 and 3 (initial seeds)
        if (compute_gaps) {
            result.histogram[1] += 1;  // gap between 2 and 3
            result.histogram[2] += 1;  // gap between 3 and 5
        }

        // Add +1 to class1 (for 5) and +1 to class3 (for 3) — v7-golden convention
        if (compute_gaps) {
            class1_total += 1;  // prime 5 (=== 1 mod 4)
            class3_total += 1;  // prime 3 (=== 3 mod 4)
        }

        result.class1 = class1_total;
        result.class3 = class3_total;

        // Read accumulated large gaps from GPU
        if (compute_gaps) {
            unsigned int lg_count = 0;
            check_cuda(cudaMemcpy(&lg_count, lg_cnt_d, sizeof(unsigned int),
                                  cudaMemcpyDeviceToHost),
                       "cudaMemcpy(lg_count)");

            if (lg_count > (unsigned int)VOSS_MAX_LARGE_GAPS) {
                lg_count = VOSS_MAX_LARGE_GAPS;
            }

            if (lg_count > 0) {
                result.large_gaps.resize(lg_count);
                check_cuda(cudaMemcpy(result.large_gaps.data(), large_gaps_d,
                                      lg_count * sizeof(LargeGap),
                                      cudaMemcpyDeviceToHost),
                           "cudaMemcpy(large_gaps)");
                // Sort by gap (descending)
                std::sort(result.large_gaps.begin(), result.large_gaps.end(),
                          [](const LargeGap& a, const LargeGap& b) {
                              return a.gap > b.gap;
                          });
            }
        }

        result.prime_count = total;
    }

done:
    return result;
}

} // anonymous namespace

// ============================================================
// Public C API — lifecycle
// ============================================================
extern "C" int voss_primes_ctx_new(uint64_t N, int profile,
                                   voss_primes_ctx** out_ctx) {
    if (out_ctx == nullptr) {
        voss_set_last_error("out_ctx pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    *out_ctx = nullptr;

    if (N < 2) {
        voss_set_last_error("N must be >= 2");
        return VOSS_ERR_INVALID_N;
    }
    if (N > 100000000000000ULL) {
        voss_set_last_error("N exceeds maximum (10^14)");
        return VOSS_ERR_OUT_OF_RANGE;
    }
    if (profile != VOSS_PROFILE_MINIMAL &&
        profile != VOSS_PROFILE_STANDARD &&
        profile != VOSS_PROFILE_FULL) {
        voss_set_last_error("invalid profile value");
        return VOSS_ERR_INVALID_ARG;
    }

    try {
        auto* ctx = new voss_primes_ctx();
        ctx->N = N;
        ctx->profile = profile;
        *out_ctx = ctx;
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(std::string("ctx_new failed: ") + e.what());
        return VOSS_ERR_INTERNAL;
    }
}

extern "C" void voss_primes_ctx_free(voss_primes_ctx* ctx) {
    delete ctx;
}

// ============================================================
// Internal: ensure full computation done (once)
// ============================================================
static int ensure_full_computed(voss_primes_ctx* ctx) {
    if (ctx->has_prime_count && ctx->has_histogram) {
        return VOSS_OK;  // already computed
    }
    bool need_gaps = (ctx->profile != VOSS_PROFILE_MINIMAL);
    try {
        FullResult r = compute_full_impl(ctx->N, need_gaps);
        ctx->cached_prime_count = r.prime_count;
        ctx->has_prime_count = true;
        if (need_gaps) {
            ctx->cached_histogram = std::move(r.histogram);
            ctx->has_histogram = true;
            ctx->cached_class1 = r.class1;
            ctx->cached_class3 = r.class3;
            ctx->has_chebyshev = true;
            ctx->cached_large_gaps = std::move(r.large_gaps);
            ctx->has_large_gaps = true;
        }
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_CUDA;
    } catch (...) {
        voss_set_last_error("Unknown error");
        return VOSS_ERR_INTERNAL;
    }
}

// ============================================================
// Public C API — queries
// ============================================================
extern "C" int voss_primes_ctx_prime_count(voss_primes_ctx* ctx, uint64_t* out) {
    if (ctx == nullptr) {
        voss_set_last_error("ctx is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (!ctx->has_prime_count) {
        int rc = ensure_full_computed(ctx);
        if (rc != VOSS_OK) return rc;
    }
    *out = ctx->cached_prime_count;
    return VOSS_OK;
}

static int get_gap_count(voss_primes_ctx* ctx, uint64_t* out, int gap_size) {
    if (ctx == nullptr) {
        voss_set_last_error("ctx is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (ctx->profile == VOSS_PROFILE_MINIMAL) {
        voss_set_last_error("Profile MINIMAL does not compute gap histogram; "
                            "use STANDARD or FULL");
        return VOSS_ERR_INVALID_ARG;
    }
    if (!ctx->has_histogram) {
        int rc = ensure_full_computed(ctx);
        if (rc != VOSS_OK) return rc;
    }
    *out = (uint64_t)ctx->cached_histogram[gap_size];
    return VOSS_OK;
}

// ============================================================
// M4: statistics from cached histogram
// ============================================================
extern "C" int voss_primes_ctx_statistics(voss_primes_ctx* ctx,
                                          voss_primes_stats_t* out) {
    if (ctx == nullptr) {
        voss_set_last_error("ctx is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (ctx->profile == VOSS_PROFILE_MINIMAL) {
        voss_set_last_error("Profile MINIMAL does not compute gap histogram; "
                            "use STANDARD or FULL");
        return VOSS_ERR_INVALID_ARG;
    }
    if (!ctx->has_histogram) {
        int rc = ensure_full_computed(ctx);
        if (rc != VOSS_OK) return rc;
    }

    const std::vector<int64_t>& hist = ctx->cached_histogram;

    // Pass 1: total + weighted sum
    int64_t total = 0;
    int64_t weighted = 0;
    for (int g = 1; g < VOSS_MAX_GAP; g++) {
        if (hist[g] == 0) continue;
        total    += hist[g];
        weighted += (int64_t)g * hist[g];
    }

    if (total == 0) {
        out->mean_gap    = 0.0;
        out->std_dev     = 0.0;
        out->skewness    = 0.0;
        out->kurtosis    = 0.0;
        out->total_gaps  = 0;
        return VOSS_OK;
    }

    double mean = (double)weighted / (double)total;

    // Pass 2: variance, 3rd, 4th moments
    double var_sum = 0.0, m3 = 0.0, m4 = 0.0;
    for (int g = 1; g < VOSS_MAX_GAP; g++) {
        if (hist[g] == 0) continue;
        double d = (double)g - mean;
        double d2 = d * d;
        var_sum += (double)hist[g] * d2;
        m3      += (double)hist[g] * d2 * d;
        m4      += (double)hist[g] * d2 * d2;
    }
    double var = var_sum / (double)total;
    double std_dev = std::sqrt(var);

    out->mean_gap   = mean;
    out->std_dev    = std_dev;
    out->skewness   = (std_dev > 0.0) ? (m3 / (double)total) / (var * std_dev) : 0.0;
    out->kurtosis   = (var > 0.0) ? (m4 / (double)total) / (var * var) - 3.0 : 0.0;
    out->total_gaps = (uint64_t)total;
    return VOSS_OK;
}

extern "C" int voss_primes_ctx_sophie_germain(voss_primes_ctx* ctx,
                                              uint64_t* out) {
    if (ctx == nullptr) {
        voss_set_last_error("ctx is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (out == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (ctx->profile == VOSS_PROFILE_MINIMAL) {
        voss_set_last_error("Profile MINIMAL does not support sophie_germain; "
                            "use STANDARD or FULL");
        return VOSS_ERR_INVALID_ARG;
    }

    if (ctx->has_sophie) {
        *out = ctx->cached_sophie;
        return VOSS_OK;
    }

    // Sophie Germain: count p where p and 2*p+1 are both prime.
    // We have the list of all primes up to N from the histogram pipeline.
    // Approach: iterate prime positions to reconstruct prime values, then
    // apply Miller-Rabin on 2*p+1.
    // For performance: use the histogram-cached prime list if we had it,
    // but we don't store the full list. Simpler: recompute primes from
    // the histogram is not possible directly.
    //
    // Pragmatic approach: for now, use a CPU sieve up to N and count.
    // For N up to 10^7 this is fast enough. For larger N we'd need GPU
    // reconstruction of primes (planned for later M5.x).
    try {
        if (ctx->N > 50000000ULL) {
            voss_set_last_error("sophie_germain currently supports N <= 5e7");
            return VOSS_ERR_OUT_OF_RANGE;
        }
        uint64_t N = ctx->N;
        std::vector<bool> is_prime(N + 1, true);
        if (N >= 0) is_prime[0] = false;
        if (N >= 1) is_prime[1] = false;
        for (uint64_t i = 2; i * i <= N; i++) {
            if (is_prime[i]) {
                for (uint64_t j = i * i; j <= N; j += i) is_prime[j] = false;
            }
        }
        uint64_t count = 0;
        for (uint64_t p = 2; p <= N; p++) {
            if (!is_prime[p]) continue;
            uint64_t q = 2 * p + 1;
            if (q > N && voss_is_prime_mr(q)) count++;
            else if (q <= N && is_prime[q]) count++;
        }
        ctx->cached_sophie = count;
        ctx->has_sophie = true;
        *out = count;
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_INTERNAL;
    }
}

extern "C" int voss_primes_ctx_large_gaps_count(voss_primes_ctx* ctx,
                                                uint64_t* out_count) {
    if (ctx == nullptr || out_count == nullptr) {
        voss_set_last_error("null pointer");
        return VOSS_ERR_INVALID_ARG;
    }
    if (ctx->profile == VOSS_PROFILE_MINIMAL) {
        voss_set_last_error("Profile MINIMAL does not compute large gaps");
        return VOSS_ERR_INVALID_ARG;
    }
    if (!ctx->has_large_gaps) {
        int rc = ensure_full_computed(ctx);
        if (rc != VOSS_OK) return rc;
    }
    *out_count = (uint64_t)ctx->cached_large_gaps.size();
    return VOSS_OK;
}

extern "C" int voss_primes_ctx_large_gaps_get(voss_primes_ctx* ctx,
                                              uint64_t index,
                                              uint64_t* out_position,
                                              uint32_t* out_gap) {
    if (ctx == nullptr || out_position == nullptr || out_gap == nullptr) {
        voss_set_last_error("null pointer");
        return VOSS_ERR_INVALID_ARG;
    }
    if (ctx->profile == VOSS_PROFILE_MINIMAL) {
        voss_set_last_error("Profile MINIMAL does not compute large gaps");
        return VOSS_ERR_INVALID_ARG;
    }
    if (!ctx->has_large_gaps) {
        int rc = ensure_full_computed(ctx);
        if (rc != VOSS_OK) return rc;
    }
    if (index >= ctx->cached_large_gaps.size()) {
        voss_set_last_error("index out of range");
        return VOSS_ERR_INVALID_ARG;
    }
    const LargeGap& lg = ctx->cached_large_gaps[index];
    *out_position = lg.position;
    *out_gap = (uint32_t)lg.gap;
    return VOSS_OK;
}

extern "C" int voss_primes_ctx_chebyshev_bias(voss_primes_ctx* ctx,
                                                uint64_t* out_pi_4_1,
                                                uint64_t* out_pi_4_3) {
    if (ctx == nullptr) {
        voss_set_last_error("ctx is null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (out_pi_4_1 == nullptr || out_pi_4_3 == nullptr) {
        voss_set_last_error("out pointers must not be null");
        return VOSS_ERR_INVALID_ARG;
    }
    if (ctx->profile == VOSS_PROFILE_MINIMAL) {
        voss_set_last_error("Profile MINIMAL does not compute Chebyshev bias; "
                            "use STANDARD or FULL");
        return VOSS_ERR_INVALID_ARG;
    }
    if (!ctx->has_chebyshev) {
        int rc = ensure_full_computed(ctx);
        if (rc != VOSS_OK) return rc;
    }
    *out_pi_4_1 = ctx->cached_class1;
    *out_pi_4_3 = ctx->cached_class3;
    return VOSS_OK;
}

extern "C" int voss_primes_ctx_twins(voss_primes_ctx* ctx, uint64_t* out) {
    return get_gap_count(ctx, out, 2);
}

extern "C" int voss_primes_ctx_cousin(voss_primes_ctx* ctx, uint64_t* out) {
    return get_gap_count(ctx, out, 4);
}

extern "C" int voss_primes_ctx_sexy(voss_primes_ctx* ctx, uint64_t* out) {
    return get_gap_count(ctx, out, 6);
}
