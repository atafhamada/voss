// ============================================================
// prime_count.cu — pi(N) computation
//   Public C API: voss_primes_prime_count
//   Kernels declared in sieve.cu / extract.cu
//   Orchestration derived from v7-golden main() (gaps/chebyshev/CSV removed)
// ============================================================

#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <cstring>
#include <string>
#include <stdexcept>
#include <vector>
#include <cuda_runtime.h>

#include "voss/voss.h"
#include "voss/voss_primes.h"

// === Kernels (defined in sieve.cu, extract.cu) ===
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

// === Thread-local last error (per DESIGN.md 4.3) ===
static thread_local std::string g_last_error;

static void set_last_error(const std::string& msg) {
    g_last_error = msg;
}

// === Wheel-30 constants ===
static const int W30[8] = {1, 7, 11, 13, 17, 19, 23, 29};

// === Launch parameters for one base prime in one segment ===
struct LaunchInfo {
    uint32_t p;
    int64_t s[8];
    int grid_x;
};

// ============================================================
// Helpers (copied verbatim from v7-golden)
// ============================================================
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

// ============================================================
// RAII wrappers for CUDA resources
// ============================================================
namespace {

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

} // anonymous namespace

// ============================================================
// Internal: compute pi(N) — throws std::exception on error
// ============================================================
static uint64_t compute_prime_count(uint64_t N) {
    // Small N handled directly
    if (N < 3)  return 1;  // N=2 -> 1
    if (N < 5)  return 2;  // N=3,4 -> 2
    if (N < 7)  return 3;  // N=5,6 -> 3

    // Check CUDA availability early
    int device_count = 0;
    check_cuda(cudaGetDeviceCount(&device_count), "cudaGetDeviceCount");
    if (device_count == 0) {
        throw std::runtime_error("No CUDA device available");
    }

    // === Segment parameters (same as v7-golden) ===
    const int64_t SEG_NUM = 100000000020LL;
    const int64_t SEG_K   = SEG_NUM / 30;
    const int64_t SEG_BITS = SEG_K * 8;
    const int64_t NUM_SEG = (N + SEG_NUM - 1) / SEG_NUM;

    // === Base primes up to sqrt(N) ===
    int limit = (int)std::sqrt((double)N) + 1;
    BasePrimes base(limit);

    // === Buffer sizing ===
    // M0 simplification: buffer sized to hold all primes <= N in one segment.
    // For N=10^9, this is ~50M uint64 = ~400 MB.
    int64_t max_pos = (int64_t)(N / 2) + 1000;

    int64_t seg_words = (SEG_BITS + 31) / 32;
    size_t bits_bytes = (size_t)seg_words * sizeof(uint32_t);
    size_t pos_bytes  = (size_t)max_pos * sizeof(uint64_t);

    // === Allocate GPU resources ===
    DeviceBuffer bits_buf(bits_bytes);
    DeviceBuffer pos_buf(pos_bytes);
    DeviceBuffer cnt_buf(sizeof(uint64_t));
    CudaStream stream;

    uint32_t* bits_d = bits_buf.as_u32();
    uint64_t* positions_d = pos_buf.as_u64();
    uint64_t* count_d = cnt_buf.as_u64();

    // === Initial count: 2, 3, 5 ===
    uint64_t total = 3;

    const int BLOCK = 256;
    std::vector<LaunchInfo> launches;
    launches.reserve(base.count);

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

        // === Compute launch info per base prime ===
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

        // === Build CUDA graph (bundles all sieve launches for this segment) ===
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

            // Init bits: all 1s (candidate primes), then clear bit 0 of word 0 (number 1)
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

        // === Extract positions ===
        check_cuda(cudaMemset(count_d, 0, sizeof(uint64_t)), "cudaMemset(count)");

        int ext_grid = (int)((current_seg_words + BLOCK - 1) / BLOCK);
        extract_w30_seg_kernel<<<ext_grid, BLOCK>>>(
            bits_d, current_seg_words, seg_bits, positions_d, count_d);
        check_cuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize(extract)");

        uint64_t n_pos = 0;
        check_cuda(cudaMemcpy(&n_pos, count_d, 8, cudaMemcpyDeviceToHost),
                   "cudaMemcpy(count->host)");

        if (n_pos > (uint64_t)max_pos) {
            throw std::runtime_error(
                "Position buffer overflow (increase max_pos)");
        }

        total += n_pos;
    }

    return total;
}

// ============================================================
// Public C API
// ============================================================
extern "C" int voss_primes_prime_count(uint64_t N, uint64_t* out) {
    if (N < 2) {
        set_last_error("N must be >= 2");
        return VOSS_ERR_INVALID_N;
    }
    if (out == nullptr) {
        set_last_error("out pointer is null");
        return VOSS_ERR_INVALID_ARG;
    }
    try {
        uint64_t result = compute_prime_count(N);
        *out = result;
        return VOSS_OK;
    } catch (const std::exception& e) {
        set_last_error(e.what());
        return VOSS_ERR_CUDA;
    } catch (...) {
        set_last_error("Unknown error");
        return VOSS_ERR_INTERNAL;
    }
}

extern "C" const char* voss_get_last_error(void) {
    return g_last_error.c_str();
}

extern "C" const char* voss_strerror(int code) {
    switch (code) {
        case VOSS_OK:                return "OK";
        case VOSS_ERR_INVALID_N:     return "Invalid N";
        case VOSS_ERR_OUT_OF_RANGE:  return "Out of range";
        case VOSS_ERR_NO_CUDA:       return "No CUDA device";
        case VOSS_ERR_OUT_OF_MEMORY: return "Out of memory";
        case VOSS_ERR_CUDA:          return "CUDA error";
        case VOSS_ERR_INVALID_ARG:   return "Invalid argument";
        case VOSS_ERR_INTERNAL:      return "Internal error";
        default:                     return "Unknown error";
    }
}
