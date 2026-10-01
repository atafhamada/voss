// ============================================================
// goldbach_upto.cu — GPU test of Goldbach conjecture up to N (M6)
//
// Uses existing GPU sieve (voss_primes_in_range) to get all primes
// up to N, builds a bitmap, then one thread per even n in [4, N]
// checks for existence of a Goldbach pair via O(1) bitmap lookup.
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <stdexcept>
#include <string>
#include <cuda_runtime.h>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"

__device__ inline bool dbm_get(const uint64_t* __restrict__ bm, uint64_t x) {
    return (bm[x >> 6] >> (x & 63)) & 1ULL;
}

__global__ void goldbach_check_kernel(
    const uint64_t* __restrict__ bm,
    const uint64_t* __restrict__ primes,
    uint64_t np,
    uint64_t N,
    uint64_t* __restrict__ ce,
    unsigned long long* __restrict__ ce_count,
    uint64_t max_ce)
{
    uint64_t idx = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t n = 4 + idx * 2;
    if (n > N) return;

    uint64_t half = n / 2;
    for (uint64_t i = 0; i < np; i++) {
        uint64_t p = primes[i];
        if (p > half) break;
        if (dbm_get(bm, n - p)) return;
    }
    unsigned long long slot = atomicAdd(ce_count, 1ULL);
    if (slot < max_ce) ce[slot] = n;
}

extern "C" int voss_primes_goldbach_test_upto(
    uint64_t N,
    uint64_t** out_ce,
    uint64_t* out_count,
    uint64_t max_ce)
{
    if (!out_ce || !out_count) {
        voss_set_last_error("null pointer");
        return VOSS_ERR_INVALID_ARG;
    }
    *out_ce = nullptr;
    *out_count = 0;
    if (N < 4) {
        voss_set_last_error("N must be >= 4");
        return VOSS_ERR_INVALID_N;
    }
    if (max_ce == 0) return VOSS_OK;

    uint64_t* host_primes = nullptr;
    uint64_t num_primes = 0;
    // Use dynamic limit based on N (in_range hardcodes 10^7; insufficient for N >= 10^9)
    // pi(N) <= N / (ln(N) - 1) approximately; use N/8 + 1000 as safe upper bound
    uint64_t max_primes = (N / 8) + 1000;
    if (max_primes > 100000000ULL) max_primes = 100000000ULL;  // cap at 100M (800 MB)
    int rc = voss_primes_in_range_with_limit(2, N, max_primes, &host_primes, &num_primes);
    if (rc != VOSS_OK) return rc;

    struct PGuard { uint64_t* p; ~PGuard(){ if(p) free(p); } } pg{host_primes};

    uint64_t words = (N + 64) / 64;
    std::vector<uint64_t> bm(words, 0);
    // Always seed with 2, 3, 5 (in_range's W30 wheel starts at 7)
    if (N >= 2) bm[2 >> 6] |= (1ULL << (2 & 63));
    if (N >= 3) bm[3 >> 6] |= (1ULL << (3 & 63));
    if (N >= 5) bm[5 >> 6] |= (1ULL << (5 & 63));
    for (uint64_t i = 0; i < num_primes; i++) {
        uint64_t p = host_primes[i];
        if (p > N) continue;  // safety
        bm[p >> 6] |= (1ULL << (p & 63));
    }

    // Build final primes vector: prepend 2, 3, 5 (in_range's W30 starts at 7)
    std::vector<uint64_t> primes_vec;
    if (N >= 2) primes_vec.push_back(2);
    if (N >= 3) primes_vec.push_back(3);
    if (N >= 5) primes_vec.push_back(5);
    for (uint64_t i = 0; i < num_primes; i++) {
        if (host_primes[i] > 5) primes_vec.push_back(host_primes[i]);
    }
    uint64_t total_primes = (uint64_t)primes_vec.size();

    uint64_t* d_bm = nullptr;
    uint64_t* d_pr = nullptr;
    uint64_t* d_ce = nullptr;
    unsigned long long* d_cc = nullptr;
    int rc2 = VOSS_OK;
    try {
        cudaError_t e;
        e = cudaMalloc(&d_bm, words * sizeof(uint64_t));
        if (e) throw std::runtime_error("cudaMalloc bm");
        e = cudaMalloc(&d_pr, total_primes * sizeof(uint64_t));
        if (e) throw std::runtime_error("cudaMalloc primes");
        e = cudaMalloc(&d_ce, max_ce * sizeof(uint64_t));
        if (e) throw std::runtime_error("cudaMalloc ce");
        e = cudaMalloc(&d_cc, sizeof(unsigned long long));
        if (e) throw std::runtime_error("cudaMalloc cc");
        e = cudaMemset(d_cc, 0, sizeof(unsigned long long));
        if (e) throw std::runtime_error("cudaMemset");
        e = cudaMemcpy(d_bm, bm.data(), words * sizeof(uint64_t), cudaMemcpyHostToDevice);
        if (e) throw std::runtime_error("memcpy bm");
        e = cudaMemcpy(d_pr, primes_vec.data(), total_primes * sizeof(uint64_t), cudaMemcpyHostToDevice);
        if (e) throw std::runtime_error("memcpy primes");

        uint64_t num_n = (N - 4) / 2 + 1;
        int threads = 256;
        int blocks = (int)((num_n + threads - 1) / threads);
        goldbach_check_kernel<<<blocks, threads>>>(d_bm, d_pr, total_primes, N, d_ce, d_cc, max_ce);
        e = cudaDeviceSynchronize();
        if (e) throw std::runtime_error(std::string("kernel: ") + cudaGetErrorString(e));

        unsigned long long hcc = 0;
        e = cudaMemcpy(&hcc, d_cc, sizeof(unsigned long long), cudaMemcpyDeviceToHost);
        if (e) throw std::runtime_error("memcpy count back");

        uint64_t to_ret = (hcc < max_ce) ? hcc : max_ce;
        if (to_ret > 0) {
            uint64_t* out = (uint64_t*)malloc(to_ret * sizeof(uint64_t));
            if (!out) throw std::runtime_error("host malloc");
            e = cudaMemcpy(out, d_ce, to_ret * sizeof(uint64_t), cudaMemcpyDeviceToHost);
            if (e) { free(out); throw std::runtime_error("memcpy ce back"); }
            *out_ce = out;
            *out_count = to_ret;
        }
    } catch (const std::exception& ex) {
        voss_set_last_error(ex.what());
        rc2 = VOSS_ERR_INTERNAL;
    }
    if (d_bm) cudaFree(d_bm);
    if (d_pr) cudaFree(d_pr);
    if (d_ce) cudaFree(d_ce);
    if (d_cc) cudaFree(d_cc);
    return rc2;
}
