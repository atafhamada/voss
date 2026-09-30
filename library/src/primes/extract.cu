// ============================================================
// extract.cu — position extraction kernel
// Copied verbatim from src/voss_w30_v7.cu (v7-golden)
// Do not modify logic.
// ============================================================

#include <cstdint>
#include <cuda_runtime.h>

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
