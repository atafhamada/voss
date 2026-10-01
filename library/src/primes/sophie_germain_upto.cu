// ============================================================
// sophie_germain_upto.cu — GPU kernel for Sophie Germain count
//
// Sophie Germain prime p: p and 2*p+1 are both prime.
// This file contains ONLY the device kernel + helper.
// The host wrapper (voss_primes_ctx_sophie_germain_upto) lives
// in context.cu where struct voss_primes_ctx is fully defined.
// ============================================================

#include <cstdint>
#include <cuda_runtime.h>

// Bitmap lookup. Named distinctly (sg = sophie germain) and marked
// static to avoid symbol collision with goldbach_upto.cu.
static __device__ inline bool dbm_get_sg(const uint64_t* __restrict__ bm,
                                         uint64_t x) {
    return (bm[x >> 6] >> (x & 63)) & 1ULL;
}

// One thread per prime p <= N. Checks bitmap at 2p+1; atomically
// increments the global counter on success.
extern "C" __global__ void sophie_germain_kernel(
    const uint64_t* __restrict__ bm,
    const uint64_t* __restrict__ primes,
    uint64_t np,
    unsigned long long* __restrict__ out_count)
{
    uint64_t idx = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= np) return;
    uint64_t p = primes[idx];
    uint64_t q = 2 * p + 1;
    if (dbm_get_sg(bm, q)) atomicAdd(out_count, 1ULL);
}
