// ============================================================
// chebyshev.cu — mod-4 prime count kernel (M4)
// Copied verbatim from src/voss_w30_v7.cu (v7-golden).
// ============================================================

#include <cstdint>
#include <cuda_runtime.h>

__constant__ int W30_DEV_CHEB[8] = {1, 7, 11, 13, 17, 19, 23, 29};

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
    uint64_t val = 30ULL * (k_base + (idx >> 3)) + (uint64_t)W30_DEV_CHEB[idx & 7];
    uint32_t r = (uint32_t)(val & 3);
    if (r == 1) atomicAdd(cnt1, 1ULL);
    else if (r == 3) atomicAdd(cnt3, 1ULL);
}
