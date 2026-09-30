// ============================================================
// range.cu — voss_primes_in_range / _with_limit (M3)
//
// Sieves the range [a, b] using the existing Wheel-30 kernels.
// The range is aligned to Wheel-30 boundaries, sieved as a single
// segment, then positions are filtered for [a, b].
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <string>
#include <stdexcept>
#include <vector>
#include <algorithm>
#include <cuda_runtime.h>
#include <thrust/sort.h>
#include <thrust/device_ptr.h>

#include "voss/voss.h"
#include "voss/voss_primes.h"
#include "core/internal.hpp"

// === Kernel forward declarations ===
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

struct DeviceBuffer {
    void* ptr = nullptr;
    explicit DeviceBuffer(size_t bytes) {
        if (bytes == 0) bytes = 4;  // avoid zero-size alloc
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
};

inline void check_cuda(cudaError_t err, const char* what) {
    if (err != cudaSuccess) {
        throw std::runtime_error(
            std::string(what) + " failed: " + cudaGetErrorString(err));
    }
}

} // anonymous namespace

// ============================================================
// Internal implementation — throws on error
// ============================================================
static std::vector<uint64_t> primes_in_range_impl(uint64_t a, uint64_t b,
                                                  uint64_t max_count) {
    std::vector<uint64_t> result;

    // Normalize
    if (a < 2) a = 2;
    if (b < a) return result;

    // Small cases: hardcode via trial division (fast for tiny ranges)
    if (b <= 100) {
        for (uint64_t n = a; n <= b; n++) {
            bool is_p = (n >= 2);
            for (uint64_t d = 2; d * d <= n; d++) {
                if (n % d == 0) { is_p = false; break; }
            }
            if (is_p) result.push_back(n);
        }
        return result;
    }

    // Check CUDA availability
    int device_count = 0;
    check_cuda(cudaGetDeviceCount(&device_count), "cudaGetDeviceCount");
    if (device_count == 0) {
        throw std::runtime_error("No CUDA device available");
    }

    // === Align to Wheel-30 boundaries ===
    // k_base: the K value corresponding to the number 30*k_base + residue.
    // We want the segment to cover [a, b]. Choose k_base and k_end such that
    // all numbers in [a, b] are covered.
    int64_t k_base = (int64_t)(a / 30);
    int64_t k_end  = (int64_t)(b / 30) + 1;  // exclusive
    int64_t num_k  = k_end - k_base;
    int64_t seg_bits = num_k * 8;
    int64_t seg_words = (seg_bits + 31) / 32;

    // === Base primes up to sqrt(b) ===
    int limit = (int)std::sqrt((double)b) + 1;
    uint32_t* base_arr = nullptr;
    int base_count = 0;
    generate_base_primes(limit, &base_arr, &base_count);
    struct BasePrimesGuard {
        uint32_t* p;
        ~BasePrimesGuard() { if (p) free(p); }
    } bp_guard{base_arr};

    // === Allocate GPU buffers ===
    // positions buffer: bounded by max_count
    size_t pos_bytes = (size_t)max_count * sizeof(uint64_t);
    DeviceBuffer bits_buf((size_t)seg_words * sizeof(uint32_t));
    DeviceBuffer pos_buf(pos_bytes);
    DeviceBuffer cnt_buf(sizeof(uint64_t));
    cudaStream_t stream;
    check_cuda(cudaStreamCreate(&stream), "cudaStreamCreate");
    struct StreamGuard {
        cudaStream_t s;
        ~StreamGuard() { if (s) cudaStreamDestroy(s); }
    } sg{stream};

    uint32_t* bits_d = bits_buf.as_u32();
    uint64_t* positions_d = pos_buf.as_u64();
    uint64_t* count_d = cnt_buf.as_u64();

    // === Build launches for each base prime ===
    const int BLOCK = 256;
    struct LaunchInfo { uint32_t p; int64_t s[8]; int grid_x; };
    std::vector<LaunchInfo> launches;
    launches.reserve(base_count);

    int64_t seg_low_num = k_base * 30;   // segment covers [seg_low_num, seg_low_num + num_k*30 - 1]
    int64_t seg_high_num = k_end * 30 - 1;

    for (int i = 0; i < base_count; i++) {
        uint32_t p = base_arr[i];
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

    // === Run sieve (no CUDA graph — single segment, launch count is small) ===
    // Init bits to all 1s
    check_cuda(cudaMemset(bits_d, 0xFF, (size_t)seg_words * sizeof(uint32_t)),
               "cudaMemset(bits)");
    // Clear bit for number 1 if it's in the segment
    if (k_base == 0) {
        // Bit index for 1 is (0 - 0)*8 + 0 = 0 (residue 1 at o=0)
        uint32_t first_word = 0xFFFFFFFE;
        check_cuda(cudaMemcpy(bits_d, &first_word, 4, cudaMemcpyHostToDevice),
                   "cudaMemcpy(first word)");
    }

    for (auto& L : launches) {
        sieve_w30_seg_kernel<<<L.grid_x, BLOCK, 0, stream>>>(
            bits_d, L.p, L.s[0], L.s[1], L.s[2], L.s[3],
            L.s[4], L.s[5], L.s[6], L.s[7], seg_bits);
    }
    check_cuda(cudaStreamSynchronize(stream), "cudaStreamSynchronize(sieve)");

    // === Extract positions ===
    check_cuda(cudaMemset(count_d, 0, sizeof(uint64_t)), "cudaMemset(count)");
    int ext_grid = (int)((seg_words + BLOCK - 1) / BLOCK);
    extract_w30_seg_kernel<<<ext_grid, BLOCK>>>(
        bits_d, seg_words, seg_bits, positions_d, count_d);
    check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize(extract)");

    uint64_t n_pos = 0;
    check_cuda(cudaMemcpy(&n_pos, count_d, 8, cudaMemcpyDeviceToHost),
               "cudaMemcpy(count->host)");

    // === Sort positions (extract order is non-deterministic) ===
    if (n_pos > 0) {
        thrust::device_ptr<uint64_t> ptr(positions_d);
        thrust::sort(ptr, ptr + n_pos);
        check_cuda(cudaDeviceSynchronize(), "thrust::sort");
    }

    // === Read positions and convert to prime values ===
    if (n_pos > 0) {
        std::vector<uint64_t> host_positions(n_pos);
        check_cuda(cudaMemcpy(host_positions.data(), positions_d,
                              n_pos * sizeof(uint64_t), cudaMemcpyDeviceToHost),
                   "cudaMemcpy(positions)");

        result.reserve(n_pos);
        for (uint64_t idx : host_positions) {
            int64_t k_local = idx >> 3;
            int o = idx & 7;
            uint64_t prime = 30ULL * (uint64_t)(k_base + k_local) + (uint64_t)W30[o];
            if (prime >= a && prime <= b) {
                result.push_back(prime);
            }
        }
    }

    return result;
}

// ============================================================
// Public C API
// ============================================================
extern "C" int voss_primes_in_range(uint64_t a, uint64_t b,
                                    uint64_t** out_array, uint64_t* out_count) {
    // Default limit: 10^7 primes (80 MB)
    return voss_primes_in_range_with_limit(a, b, 10000000ULL, out_array, out_count);
}

extern "C" int voss_primes_in_range_with_limit(uint64_t a, uint64_t b,
                                               uint64_t max_count,
                                               uint64_t** out_array,
                                               uint64_t* out_count) {
    if (out_array == nullptr || out_count == nullptr) {
        voss_set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    *out_array = nullptr;
    *out_count = 0;

    if (b > 100000000000000ULL) {  // 10^14
        voss_set_last_error("b exceeds maximum (10^14)");
        return VOSS_ERR_OUT_OF_RANGE;
    }
    if (max_count == 0) {
        voss_set_last_error("max_count must be > 0");
        return VOSS_ERR_INVALID_ARG;
    }

    try {
        std::vector<uint64_t> result = primes_in_range_impl(a, b, max_count);

        if (result.size() > max_count) {
            voss_set_last_error("Range contains more primes than max_count");
            return VOSS_ERR_OUT_OF_MEMORY;
        }

        if (result.empty()) {
            return VOSS_OK;  // *out_array stays NULL, *out_count = 0
        }

        // Allocate host memory (malloc'd — freed by voss_free)
        uint64_t* arr = (uint64_t*)malloc(result.size() * sizeof(uint64_t));
        if (arr == nullptr) {
            voss_set_last_error("host malloc failed");
            return VOSS_ERR_OUT_OF_MEMORY;
        }
        std::copy(result.begin(), result.end(), arr);

        *out_array = arr;
        *out_count = (uint64_t)result.size();
        return VOSS_OK;
    } catch (const std::exception& e) {
        voss_set_last_error(e.what());
        return VOSS_ERR_CUDA;
    } catch (...) {
        voss_set_last_error("Unknown error");
        return VOSS_ERR_INTERNAL;
    }
}
