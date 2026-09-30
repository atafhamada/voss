// ============================================================
// gaps.cu — gap histogram kernel
// Copied verbatim from src/voss_w30_v7.cu (v7-golden).
// Do not modify logic.
// ============================================================

#include <cstdint>
#include <cuda_runtime.h>

// === Local definitions (mirrored from v7-golden) ===
#ifndef VOSS_MAX_GAP
#define VOSS_MAX_GAP 100000
#endif
#ifndef VOSS_SHARED_HIST_SIZE
#define VOSS_SHARED_HIST_SIZE 10000
#endif
#ifndef VOSS_HIST_BLOCK
#define VOSS_HIST_BLOCK 256
#endif

// === Wheel-30 constant (mirrored) ===
__constant__ int W30_DEV_GAPS[8] = {1, 7, 11, 13, 17, 19, 23, 29};

// === LargeGap struct (mirrored; unused in M2) ===
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
    int max_large_gaps)
{
    __shared__ int local_hist[VOSS_SHARED_HIST_SIZE];
    int tid = threadIdx.x;
    for (int i = tid; i < VOSS_SHARED_HIST_SIZE; i += VOSS_HIST_BLOCK)
        local_hist[i] = 0;
    __syncthreads();

    uint64_t i = (uint64_t)blockIdx.x * VOSS_HIST_BLOCK + tid;
    if (i > 0 && i < n) {
        uint64_t idx1 = positions[i];
        uint64_t idx0 = positions[i - 1];
        uint64_t v1 = 30ULL * (k_base + (idx1 >> 3)) + (uint64_t)W30_DEV_GAPS[idx1 & 7];
        uint64_t v0 = 30ULL * (k_base + (idx0 >> 3)) + (uint64_t)W30_DEV_GAPS[idx0 & 7];
        uint64_t diff = v1 - v0;
        if (diff > 0) {
            if (diff < (uint64_t)VOSS_SHARED_HIST_SIZE) {
                atomicAdd(&local_hist[diff], 1);
            } else if (diff < (uint64_t)VOSS_MAX_GAP) {
                atomicAdd((unsigned long long*)&global_hist[diff], 1ULL);
            }
            if (diff >= (uint64_t)large_gap_threshold && diff < (uint64_t)VOSS_MAX_GAP) {
                unsigned int slot = atomicAdd(large_gap_count, 1u);
                if (slot < (unsigned int)max_large_gaps) {
                    large_gaps[slot].position = v1;
                    large_gaps[slot].gap = (int32_t)diff;
                }
            }
        }
    }
    __syncthreads();
    for (int j = tid; j < VOSS_SHARED_HIST_SIZE; j += VOSS_HIST_BLOCK) {
        int v = local_hist[j];
        if (v > 0)
            atomicAdd((unsigned long long*)&global_hist[j], (unsigned long long)v);
    }
}
