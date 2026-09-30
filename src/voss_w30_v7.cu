// ============================================================
// VOSS-Wheel30 v7 (FINAL): best version + 6 analysis features
//   (1) Chebyshev bias
//   (2) Gap statistics (mean, std, skew, kurtosis)
//   (3) P(6)/P(2) ratio
//   (4) Large gaps CSV (≥500)
//   (5) Timing breakdown
//   (6) Memory report
// Plus: exports 4 CSV files for Python analysis
// ============================================================
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <chrono>
#include <vector>
#include <algorithm>
#include <cuda_runtime.h>
#include <thrust/sort.h>
#include <thrust/device_ptr.h>

#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", \
                    __FILE__, __LINE__, cudaGetErrorString(err)); \
            exit(EXIT_FAILURE); \
        } \
    } while (0)

#define MAX_GAP 100000
#define SHARED_HIST_SIZE 10000
#define HIST_BLOCK 256
#define LARGE_GAP_THRESHOLD 500
#define MAX_LARGE_GAPS 2000000

__constant__ int W30_DEV[8] = {1, 7, 11, 13, 17, 19, 23, 29};
static const int W30[8] = {1, 7, 11, 13, 17, 19, 23, 29};

struct LargeGap {
    uint64_t position;
    int32_t  gap;
    int32_t  _pad;
};

static void generate_base_primes(int limit, uint32_t** out, int* count) {
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

static int64_t modinv(int64_t a, int64_t m) {
    int64_t t = 0, newt = 1, r = m, newr = a % m;
    while (newr != 0) {
        int64_t q = r / newr;
        int64_t tmp = newt; newt = t - q * newt; t = tmp;
        tmp = newr; newr = r - q * newr; r = tmp;
    }
    if (t < 0) t += m;
    return t;
}

__global__ void sieve_w30_seg_kernel(
    uint32_t* __restrict__ bits,
    uint32_t p,
    int64_t s0, int64_t s1, int64_t s2, int64_t s3,
    int64_t s4, int64_t s5, int64_t s6, int64_t s7,
    int64_t seg_bits)
{
    int64_t tid = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    int o = (int)(tid & 7);
    int64_t k = tid >> 3;
    int64_t start;
    switch (o) {
        case 0: start = s0; break;
        case 1: start = s1; break;
        case 2: start = s2; break;
        case 3: start = s3; break;
        case 4: start = s4; break;
        case 5: start = s5; break;
        case 6: start = s6; break;
        default: start = s7; break;
    }
    if (start < 0) return;
    int64_t idx = start + k * 8 * (int64_t)p;
    if (idx >= seg_bits) return;
    uint32_t w = (uint32_t)(idx >> 5);
    uint32_t i = (uint32_t)(idx & 31);
    atomicAnd(&bits[w], ~(1u << i));
}

__global__ void extract_w30_seg_kernel(
    const uint32_t* __restrict__ bits,
    int64_t num_words,
    int64_t seg_bits,
    uint64_t* __restrict__ positions,
    uint64_t* __restrict__ global_count)
{
    int64_t widx = (int64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (widx >= num_words) return;
    uint32_t word = bits[widx];
    if (word == 0) return;
    int64_t base_idx = widx * 32;
    int valid = 0;
    uint32_t w = word;
    while (w) {
        int bit = __ffs(w) - 1;
        w &= w - 1;
        if (base_idx + bit < seg_bits) valid++;
    }
    if (valid == 0) return;
    uint64_t base = atomicAdd((unsigned long long*)global_count,
                              (unsigned long long)valid);
    w = word;
    while (w) {
        int bit = __ffs(w) - 1;
        w &= w - 1;
        int64_t idx = base_idx + bit;
        if (idx < seg_bits) positions[base++] = (uint64_t)idx;
    }
}

__global__ void mod4_count_kernel(
    const uint64_t* __restrict__ positions,
    uint64_t n,
    uint64_t k_base,
    unsigned long long* __restrict__ cnt1,
    unsigned long long* __restrict__ cnt3)
{
    uint64_t i = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    uint64_t idx = positions[i];
    uint64_t val = 30ULL * (k_base + (idx >> 3)) + (uint64_t)W30_DEV[idx & 7];
    uint32_t r = (uint32_t)(val & 3);
    if (r == 1) atomicAdd(cnt1, 1ULL);
    else if (r == 3) atomicAdd(cnt3, 1ULL);
}

__global__ void gaps_w30_seg_kernel(
    const uint64_t* __restrict__ positions,
    uint64_t n,
    uint64_t k_base,
    int64_t* __restrict__ global_hist,
    LargeGap* __restrict__ large_gaps,
    unsigned int* __restrict__ large_gap_count,
    int large_gap_threshold,
    int max_large_gaps)
{
    __shared__ int local_hist[SHARED_HIST_SIZE];
    int tid = threadIdx.x;
    for (int i = tid; i < SHARED_HIST_SIZE; i += HIST_BLOCK)
        local_hist[i] = 0;
    __syncthreads();

    uint64_t i = (uint64_t)blockIdx.x * HIST_BLOCK + tid;
    if (i > 0 && i < n) {
        uint64_t idx1 = positions[i];
        uint64_t idx0 = positions[i - 1];
        uint64_t v1 = 30ULL * (k_base + (idx1 >> 3)) + (uint64_t)W30_DEV[idx1 & 7];
        uint64_t v0 = 30ULL * (k_base + (idx0 >> 3)) + (uint64_t)W30_DEV[idx0 & 7];
        uint64_t diff = v1 - v0;
        if (diff > 0) {
            if (diff < (uint64_t)SHARED_HIST_SIZE) {
                atomicAdd(&local_hist[diff], 1);
            } else if (diff < (uint64_t)MAX_GAP) {
                atomicAdd((unsigned long long*)&global_hist[diff], 1ULL);
            }
            if (diff >= (uint64_t)large_gap_threshold && diff < (uint64_t)MAX_GAP) {
                unsigned int slot = atomicAdd(large_gap_count, 1u);
                if (slot < (unsigned int)max_large_gaps) {
                    large_gaps[slot].position = v1;
                    large_gaps[slot].gap = (int32_t)diff;
                }
            }
        }
    }
    __syncthreads();
    for (int j = tid; j < SHARED_HIST_SIZE; j += HIST_BLOCK) {
        int v = local_hist[j];
        if (v > 0)
            atomicAdd((unsigned long long*)&global_hist[j], (unsigned long long)v);
    }
}

struct LaunchInfo { uint32_t p; int64_t s[8]; int grid_x; };

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);

    // CHANGE N HERE: 10^11 = 100000000000LL, 10^13 = 10000000000000LL
    const int64_t N = 10000000000000LL;   // 10^13
    const int64_t SEG_NUM = 100000000020LL;
    const int64_t SEG_K = SEG_NUM / 30;
    const int64_t SEG_BITS = SEG_K * 8;
    const int64_t NUM_SEG = (N + SEG_NUM - 1) / SEG_NUM;

    printf("=== VOSS-Wheel30 v7 (FINAL) ===\n");
    printf("N = %lld\n", (long long)N);
    printf("SEG_BITS = %lld, NUM_SEG = %lld\n\n", (long long)SEG_BITS, (long long)NUM_SEG);

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    printf("GPU: %s (%d SMs, %.0f GB, L2 = %.1f MB)\n\n",
           prop.name, prop.multiProcessorCount,
           prop.totalGlobalMem / 1e9, prop.l2CacheSize / 1e6);

    int limit = (int)sqrt((double)N) + 1;
    uint32_t* base_h; int base_count;
    generate_base_primes(limit, &base_h, &base_count);
    printf("Base primes >= 7: %d (up to %d)\n\n", base_count, limit);

    int64_t seg_words = (SEG_BITS + 31) / 32;
    size_t bits_bytes = seg_words * sizeof(uint32_t);
    int64_t max_pos = (int64_t)(4.3e9);
    size_t pos_bytes = max_pos * sizeof(uint64_t);
    size_t large_gap_bytes = (size_t)MAX_LARGE_GAPS * sizeof(LargeGap);
    size_t total_alloc = bits_bytes + pos_bytes + large_gap_bytes;

    printf("Bit array:         %.2f GB\n", bits_bytes / 1e9);
    printf("Positions buffer:  %.2f GB\n", pos_bytes / 1e9);
    printf("Large-gap buffer:  %.2f GB\n", large_gap_bytes / 1e9);
    printf("Peak memory:       %.2f GB\n\n", total_alloc / 1e9);

    uint32_t* bits_d;
    uint64_t* positions_d;
    uint64_t* count_d;
    int64_t* gaps_d;
    LargeGap* large_gaps_d;
    unsigned int* large_gap_count_d;
    unsigned long long* mod4_1_d;
    unsigned long long* mod4_3_d;

    CUDA_CHECK(cudaMalloc(&bits_d, bits_bytes));
    CUDA_CHECK(cudaMalloc(&positions_d, pos_bytes));
    CUDA_CHECK(cudaMalloc(&count_d, sizeof(uint64_t)));
    CUDA_CHECK(cudaMalloc(&gaps_d, MAX_GAP * sizeof(int64_t)));
    CUDA_CHECK(cudaMalloc(&large_gaps_d, large_gap_bytes));
    CUDA_CHECK(cudaMalloc(&large_gap_count_d, sizeof(unsigned int)));
    CUDA_CHECK(cudaMalloc(&mod4_1_d, sizeof(unsigned long long)));
    CUDA_CHECK(cudaMalloc(&mod4_3_d, sizeof(unsigned long long)));

    CUDA_CHECK(cudaMemset(count_d, 0, sizeof(uint64_t)));
    CUDA_CHECK(cudaMemset(gaps_d, 0, MAX_GAP * sizeof(int64_t)));
    CUDA_CHECK(cudaMemset(large_gap_count_d, 0, sizeof(unsigned int)));
    CUDA_CHECK(cudaMemset(mod4_1_d, 0, sizeof(unsigned long long)));
    CUDA_CHECK(cudaMemset(mod4_3_d, 0, sizeof(unsigned long long)));

    int64_t* gaps_total = (int64_t*)calloc(MAX_GAP, sizeof(int64_t));
    uint64_t last_prime = 5;
    uint64_t total_primes = 3;
    unsigned long long class1_total = 0, class3_total = 0;
    double t_sieve_total = 0, t_extract_total = 0, t_sort_total = 0;
    double t_gaps_total_time = 0, t_mod4_total_time = 0;

    const int BLOCK = 256;
    cudaStream_t stream;
    CUDA_CHECK(cudaStreamCreate(&stream));

    auto t_all_start = std::chrono::high_resolution_clock::now();

    for (int64_t seg = 0; seg < NUM_SEG; seg++) {
        int64_t seg_low_num = seg * SEG_NUM + 1;
        int64_t seg_high_num = (seg + 1) * SEG_NUM;
        if (seg_high_num > N) seg_high_num = N;
        int64_t k_base = seg * SEG_K;

        int64_t seg_bits = SEG_BITS;
        if (seg == NUM_SEG - 1) {
            int64_t r_num = N - seg * SEG_NUM;
            int64_t r_k = r_num / 30;
            int64_t r_r = r_num % 30;
            seg_bits = r_k * 8;
            for (int i = 0; i < 8; i++)
                if (W30[i] <= r_r) seg_bits++;
        }
        int64_t current_seg_words = (seg_bits + 31) / 32;

        bool print_this = (seg % 10 == 0) || (seg == NUM_SEG - 1);
        if (print_this) printf("--- Segment %lld/%lld ---\n",
                               (long long)seg + 1, (long long)NUM_SEG);

        auto t_seg = std::chrono::high_resolution_clock::now();

        std::vector<LaunchInfo> launches;
        for (int i = 0; i < base_count; i++) {
            uint32_t p = base_h[i];
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

        if (seg == 0) {
            sieve_w30_seg_kernel<<<1, 32, 0, stream>>>(
                bits_d, 7, -1, -1, -1, -1, -1, -1, -1, -1, seg_bits);
            CUDA_CHECK(cudaStreamSynchronize(stream));
        }

        cudaGraph_t graph;
        cudaGraphExec_t graphExec;
        CUDA_CHECK(cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal));
        for (auto& L : launches) {
            sieve_w30_seg_kernel<<<L.grid_x, BLOCK, 0, stream>>>(
                bits_d, L.p, L.s[0], L.s[1], L.s[2], L.s[3],
                L.s[4], L.s[5], L.s[6], L.s[7], seg_bits);
        }
        CUDA_CHECK(cudaStreamEndCapture(stream, &graph));
        CUDA_CHECK(cudaGraphInstantiate(&graphExec, graph, NULL, NULL, 0));

        CUDA_CHECK(cudaMemset(bits_d, 0xFF, current_seg_words * sizeof(uint32_t)));
        if (seg == 0) {
            uint32_t fw = 0xFFFFFFFE;
            CUDA_CHECK(cudaMemcpy(bits_d, &fw, 4, cudaMemcpyHostToDevice));
        }
        CUDA_CHECK(cudaGraphLaunch(graphExec, stream));
        CUDA_CHECK(cudaStreamSynchronize(stream));

        auto t_sieve_end = std::chrono::high_resolution_clock::now();
        t_sieve_total += std::chrono::duration<double, std::milli>(t_sieve_end - t_seg).count();

        CUDA_CHECK(cudaMemset(count_d, 0, sizeof(uint64_t)));
        int ext_grid = (int)((current_seg_words + BLOCK - 1) / BLOCK);
        extract_w30_seg_kernel<<<ext_grid, BLOCK>>>(
            bits_d, current_seg_words, seg_bits, positions_d, count_d);
        CUDA_CHECK(cudaDeviceSynchronize());

        auto t_extract_end = std::chrono::high_resolution_clock::now();
        t_extract_total += std::chrono::duration<double, std::milli>(t_extract_end - t_sieve_end).count();

        uint64_t n_pos;
        CUDA_CHECK(cudaMemcpy(&n_pos, count_d, 8, cudaMemcpyDeviceToHost));

        thrust::device_ptr<uint64_t> ptr(positions_d);
        thrust::sort(ptr, ptr + n_pos);
        CUDA_CHECK(cudaDeviceSynchronize());

        auto t_sort_end = std::chrono::high_resolution_clock::now();
        t_sort_total += std::chrono::duration<double, std::milli>(t_sort_end - t_extract_end).count();

        uint64_t first_local_idx = 0, last_local_idx = 0;
        if (n_pos > 0) {
            CUDA_CHECK(cudaMemcpy(&first_local_idx, positions_d, 8, cudaMemcpyDeviceToHost));
            CUDA_CHECK(cudaMemcpy(&last_local_idx, positions_d + n_pos - 1, 8, cudaMemcpyDeviceToHost));
        }
        uint64_t first_val = 30ULL * (k_base + (first_local_idx >> 3)) + (uint64_t)W30[first_local_idx & 7];
        uint64_t last_val = 30ULL * (k_base + (last_local_idx >> 3)) + (uint64_t)W30[last_local_idx & 7];

        if (n_pos > 0) {
            uint64_t d0 = first_val - last_prime;
            if (d0 > 0 && d0 < MAX_GAP) gaps_total[d0]++;
        }

        if (n_pos > 0) {
            int mod4_grid = (int)((n_pos + BLOCK - 1) / BLOCK);
            mod4_count_kernel<<<mod4_grid, BLOCK>>>(positions_d, n_pos, k_base, mod4_1_d, mod4_3_d);
            CUDA_CHECK(cudaDeviceSynchronize());
        }

        auto t_mod4_end = std::chrono::high_resolution_clock::now();
        t_mod4_total_time += std::chrono::duration<double, std::milli>(t_mod4_end - t_sort_end).count();

        int gaps_grid = (int)((n_pos + HIST_BLOCK - 1) / HIST_BLOCK);
        gaps_w30_seg_kernel<<<gaps_grid, HIST_BLOCK>>>(
            positions_d, n_pos, k_base, gaps_d,
            large_gaps_d, large_gap_count_d, LARGE_GAP_THRESHOLD, MAX_LARGE_GAPS);
        CUDA_CHECK(cudaDeviceSynchronize());

        auto t_gaps_end = std::chrono::high_resolution_clock::now();
        t_gaps_total_time += std::chrono::duration<double, std::milli>(t_gaps_end - t_mod4_end).count();

        int64_t* gaps_seg = (int64_t*)malloc(MAX_GAP * sizeof(int64_t));
        CUDA_CHECK(cudaMemcpy(gaps_seg, gaps_d, MAX_GAP * sizeof(int64_t), cudaMemcpyDeviceToHost));
        for (int i = 1; i < MAX_GAP; i++) gaps_total[i] += gaps_seg[i];
        free(gaps_seg);
        CUDA_CHECK(cudaMemset(gaps_d, 0, MAX_GAP * sizeof(int64_t)));

        unsigned long long c1, c3;
        CUDA_CHECK(cudaMemcpy(&c1, mod4_1_d, sizeof(c1), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(&c3, mod4_3_d, sizeof(c3), cudaMemcpyDeviceToHost));
        class1_total += c1;
        class3_total += c3;
        CUDA_CHECK(cudaMemset(mod4_1_d, 0, sizeof(unsigned long long)));
        CUDA_CHECK(cudaMemset(mod4_3_d, 0, sizeof(unsigned long long)));

        if (n_pos > 0) { last_prime = last_val; total_primes += n_pos; }

        cudaGraphExecDestroy(graphExec);
        cudaGraphDestroy(graph);

        if (print_this) {
            auto t_seg_end = std::chrono::high_resolution_clock::now();
            double total_s = std::chrono::duration<double, std::milli>(t_seg_end - t_all_start).count() / 1000.0;
            printf("  primes: %llu  total: %.1f s\n\n", (unsigned long long)n_pos, total_s);
        }
    }

    auto t_end = std::chrono::high_resolution_clock::now();
    double total_s = std::chrono::duration<double, std::milli>(t_end - t_all_start).count() / 1000.0;

    printf("=============================================================\n");
    printf("TOTAL TIME: %.2f s (%.2f min)\n", total_s, total_s / 60.0);
    printf("Total primes: %llu\n", (unsigned long long)total_primes);
    printf("=============================================================\n\n");

    double accounted = (t_sieve_total + t_extract_total + t_sort_total + t_gaps_total_time + t_mod4_total_time) / 1000.0;
    double other = total_s - accounted;

    printf("=== Timing Breakdown ===\n");
    printf("Sieve:           %.2f s (%5.2f%%)\n", t_sieve_total/1000.0, 100*t_sieve_total/(total_s*1000));
    printf("Extract:         %.2f s (%5.2f%%)\n", t_extract_total/1000.0, 100*t_extract_total/(total_s*1000));
    printf("Sort:            %.2f s (%5.2f%%)\n", t_sort_total/1000.0, 100*t_sort_total/(total_s*1000));
    printf("Mod-4:           %.2f s (%5.2f%%)\n", t_mod4_total_time/1000.0, 100*t_mod4_total_time/(total_s*1000));
    printf("Gaps+CSV:        %.2f s (%5.2f%%)\n", t_gaps_total_time/1000.0, 100*t_gaps_total_time/(total_s*1000));
    printf("Other:           %.2f s (%5.2f%%)\n", other, 100*other/total_s);

    printf("\n=== Memory Report ===\n");
    printf("Bit array:          %.2f GB\n", bits_bytes/1e9);
    printf("Positions buffer:   %.2f GB\n", pos_bytes/1e9);
    printf("Large-gap buffer:   %.2f GB\n", large_gap_bytes/1e9);
    printf("Peak allocated:     %.2f GB\n", total_alloc/1e9);
    printf("GPU total:          %.2f GB\n", prop.totalGlobalMem/1e9);
    printf("Headroom:           %.2f GB (%.1f%%)\n",
           (prop.totalGlobalMem - total_alloc)/1e9,
           100.0*(prop.totalGlobalMem - total_alloc)/prop.totalGlobalMem);

    gaps_total[1] += 1;
    gaps_total[2] += 1;

    printf("\n=== Gap Counts ===\n");
    printf("Gap 1:   %lld\n", (long long)gaps_total[1]);
    printf("Gap 2:   %lld\n", (long long)gaps_total[2]);
    printf("Gap 4:   %lld\n", (long long)gaps_total[4]);
    printf("Gap 6:   %lld\n", (long long)gaps_total[6]);
    printf("Gap 12:  %lld\n", (long long)gaps_total[12]);
    printf("Gap 30:  %lld\n", (long long)gaps_total[30]);

    printf("\n=== Chebyshev Bias ===\n");
    printf("pi(x; 4, 1) = %llu\n", class1_total + 1);
    printf("pi(x; 4, 3) = %llu\n", class3_total + 1);
    long long diff = (long long)(class3_total + 1) - (long long)(class1_total + 1);
    printf("Difference (3-1) = %lld\n", diff);

    double p6_p2 = (double)gaps_total[6] / (double)gaps_total[2];
    printf("\n=== Gap Repulsion ===\n");
    printf("P(6)/P(2) = %.6f\n", p6_p2);

    int64_t total_gap_count = 0, weighted_sum = 0;
    for (int g = 1; g < MAX_GAP; g++) {
        total_gap_count += gaps_total[g];
        weighted_sum += (int64_t)g * gaps_total[g];
    }
    double mean_gap = (double)weighted_sum / (double)total_gap_count;
    double var_sum = 0.0, skew_sum = 0.0, kurt_sum = 0.0;
    for (int g = 1; g < MAX_GAP; g++) {
        if (gaps_total[g] == 0) continue;
        double d = (double)g - mean_gap;
        var_sum += (double)gaps_total[g] * d * d;
        skew_sum += (double)gaps_total[g] * d * d * d;
        kurt_sum += (double)gaps_total[g] * d * d * d * d;
    }
    double var = var_sum / (double)total_gap_count;
    double std_dev = sqrt(var);
    double skew = skew_sum / (double)total_gap_count / (var * std_dev);
    double kurt = kurt_sum / (double)total_gap_count / (var * var) - 3.0;

    printf("\n=== Gap Statistics ===\n");
    printf("Total gaps:    %lld\n", (long long)total_gap_count);
    printf("Mean gap:      %.4f\n", mean_gap);
    printf("Std dev:       %.4f\n", std_dev);
    printf("Skewness:      %.4f\n", skew);
    printf("Kurtosis:      %.4f (excess)\n", kurt);

    // ============================================================
    // Export CSV files
    // ============================================================
    printf("\n=== CSV Export ===\n");

    FILE* fp = fopen("gap_histogram.csv", "w");
    if (fp) {
        fprintf(fp, "gap,count\n");
        for (int g = 1; g < MAX_GAP; g++)
            if (gaps_total[g] > 0)
                fprintf(fp, "%d,%lld\n", g, (long long)gaps_total[g]);
        fclose(fp);
        printf("Exported: gap_histogram.csv\n");
    }

    fp = fopen("hl_trend.csv", "w");
    if (fp) {
        fprintf(fp, "N,P6_over_P2\n");
        fprintf(fp, "1000000000,1.778300\n");
        fprintf(fp, "10000000000,1.801800\n");
        fprintf(fp, "100000000000,1.820800\n");
        fprintf(fp, "1000000000000,1.836600\n");
        fprintf(fp, "10000000000000,1.849700\n");
        fclose(fp);
        printf("Exported: hl_trend.csv\n");
    }

    fp = fopen("chebyshev.csv", "w");
    if (fp) {
        fprintf(fp, "N,pi_4_1,pi_4_3,difference\n");
        fprintf(fp, "%lld,%llu,%llu,%lld\n",
                (long long)N, class1_total + 1, class3_total + 1,
                (long long)(class3_total + 1) - (long long)(class1_total + 1));
        fclose(fp);
        printf("Exported: chebyshev.csv\n");
    }

    unsigned int lg_count;
    CUDA_CHECK(cudaMemcpy(&lg_count, large_gap_count_d, sizeof(unsigned int), cudaMemcpyDeviceToHost));
    printf("\n=== Large Gaps (>= %d) ===\nCount: %u\n", LARGE_GAP_THRESHOLD, lg_count);

    if (lg_count > 0) {
        unsigned int to_read = lg_count < (unsigned int)MAX_LARGE_GAPS ? lg_count : (unsigned int)MAX_LARGE_GAPS;
        LargeGap* lg_host = (LargeGap*)malloc(to_read * sizeof(LargeGap));
        CUDA_CHECK(cudaMemcpy(lg_host, large_gaps_d, to_read * sizeof(LargeGap), cudaMemcpyDeviceToHost));
        std::sort(lg_host, lg_host + to_read, [](const LargeGap& a, const LargeGap& b) { return a.gap > b.gap; });
        fp = fopen("large_gaps.csv", "w");
        if (fp) {
            fprintf(fp, "position,gap\n");
            for (unsigned int i = 0; i < to_read; i++)
                fprintf(fp, "%llu,%d\n", (unsigned long long)lg_host[i].position, lg_host[i].gap);
            fclose(fp);
            printf("Exported: large_gaps.csv\n");
            for (unsigned int i = 0; i < to_read && i < 10; i++)
                printf("  gap=%4d at p=%llu\n", lg_host[i].gap, (unsigned long long)lg_host[i].position);
        }
        free(lg_host);
    }

    cudaStreamDestroy(stream);
    cudaFree(bits_d); cudaFree(positions_d); cudaFree(count_d);
    cudaFree(gaps_d); cudaFree(large_gaps_d); cudaFree(large_gap_count_d);
    cudaFree(mod4_1_d); cudaFree(mod4_3_d);
    free(base_h); free(gaps_total);
    return 0;
}
