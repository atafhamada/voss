// ============================================================
// sieve.cu — Wheel-30 segmented sieve kernel
// Copied verbatim from src/voss_w30_v7.cu (v7-golden)
// Do not modify logic.
// ============================================================

#include <cstdint>
#include <cuda_runtime.h>

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
