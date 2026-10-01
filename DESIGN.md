# DESIGN.md — Official English Version

**Version**: 1.0 (draft)
**Date**: 2026
**Author**: Ataf Hamada
**Status**: Approved for implementation

---

## Table of Contents

1. Vision and Scope
2. Architecture
3. API Design
4. Behaviors
5. Licensing and Distribution
6. Roadmap

---

# Section 1: Vision and Scope

## 1.1 What is VOSS

**[Fact from `README.md`]**: "VOSS: Vectorized Odd Segmented Sieve"

**[Fact from `README.md`]**: "Fastest open-source GPU implementation for computing prime gaps up to 10¹³"

**[Fact from `README.md`]**: "Computed all 346,065,536,839 primes up to 10¹³ and their gaps in 694.6 seconds (11.58 minutes) on a single NVIDIA A100 GPU"

**[Decision]**: VOSS will become a general library serving multiple users and functions, with the primes section first.

## 1.2 Who VOSS Is For

**[Decision]**: Multiple users. Target audience:

1. Mathematics researcher — gaps, Chebyshev, HL
2. GPU/HPC engineer — performance and flexibility
3. Student/learner — simple API
4. Python user — `pip install` then one line

**[Decision]**: Serves both casual and advanced users.

## 1.3 What VOSS Does — Primes Section

**[Fact from `voss_w30_v7.cu`]** — existing functions:
1. Sieve primes up to N
2. Count primes π(N)
3. Extract prime positions
4. Compute gaps
5. Gap histogram
6. Large gaps (≥ 500)
7. Chebyshev bias
8. Statistics (mean, std, skew, kurtosis)
9. CSV export

**[Decision]** — six new functions:
1. Twins (gap = 2)
2. Cousin (gap = 4)
3. Sexy (gap = 6)
4. Primes in range [a, b]
5. Nth prime
6. Next/Prev prime

## 1.4 What VOSS Does Not Do

**[Decision]** — planned for M5 (primes section completion):

- is_prime for single number → M5.1
- Sophie Germain primes → M5.1
- Factorization (Pollard rho) → M5.2
- Mersenne primes → M5.3
- Fermat primes → M5.3
- Goldbach partitions → M5.4

**[Decision]** — deferred to v2.0+:

- General numbers section → later
- Mathematics section → later
- ML → later
- Cloud API → later
- N > 10^13 (streaming) → v2.0+
- Multi-GPU / Cluster → v2.0+

**Current limits**:
- 10¹³ full (FULL)
- 10¹⁴ count-only (MINIMAL)

## 1.5 Competitive Advantage

**[Fact from `README.md`]**: "50-65× faster than primesieve on high-end CPU"

**[Fact from `performance.md`]**:
- primesieve on Colab CPU: 20.7× slower at 10⁹
- primesieve on Colab CPU: 12.5× slower at 10¹²

**[Decision]**: Speed is non-negotiable. Every new addition must preserve it.

## 1.6 Difference from primesieve

**[Fact from project files]**: primesieve is CPU-only, VOSS is GPU-only.

**[Inference]**: primesieve is mature (15+ years), VOSS is new and targets GPU-specific use cases.

## 1.7 Guiding Principles

**[Decision]**:

1. Speed is never sacrificed
2. Simplicity for casual users, flexibility for advanced
3. Transparency: source available for reading (BSL-1.1)
4. Verification: everything against independent sources
5. Clear limits: we state what we support and what we don't

## 1.8 Long-term Vision

**[Decision]**:

VOSS will become a platform of 3 sections:
1. Primes section (now)
2. General numbers section (later)
3. Mathematics section (later)

---

# Section 2: Architecture

## 2.1 Layer Overview

**[Decision]** — 3 layers:

```
┌─────────────────────────────────────┐
│  Python (ctypes)                    │ ← casual user
├─────────────────────────────────────┤
│  C++ Wrapper                        │ ← advanced user
├─────────────────────────────────────┤
│  C ABI                              │ ← foundation for all languages
├─────────────────────────────────────┤
│  Implementation (CUDA + CPU)        │ ← internal
└─────────────────────────────────────┘
```

## 2.2 Why C ABI First

**[Decision]**:
- C ABI is stable — doesn't break between versions
- C++ ABI changes between compilers
- ctypes calls C ABI directly
- Rust, Go, Julia can bind C ABI

## 2.3 Why C++ Wrapper

**[Decision]**:
- C ABI is primitive (int, pointers, manual free)
- C++ gives RAII, exceptions, std::vector
- C++ users benefit without complexity

## 2.4 Folder Structure

**[Decision]** — 5 folders:

```
library/
├── include/voss/         ← public C++ API
├── src/
│   ├── primes/           ← primes section
│   ├── core/             ← shared
│   └── io/               ← CSV/JSON export
├── bindings/             ← Python (ctypes)
├── tests/                ← tests
└── docs/                 ← documentation
```

## 2.5 Inside `src/primes/`

**[Decision]**:

```
src/primes/
├── context.cpp           ← handle
├── prime_count.cpp       ← π(N)
├── sieve.cu              ← kernel
├── extract.cu            ← kernel
├── gaps.cu               ← kernel
├── chebyshev.cu          ← kernel
├── range.cpp             ← primes_in_range
├── nth.cpp               ← nth_prime
└── next_prev.cpp         ← next/prev prime
```

## 2.6 Shared `src/core/`

**[Decision]**:

```
src/core/
├── error.cpp             ← return codes + global message
├── memory.cpp            ← memory management
├── cuda_context.cpp      ← CUDA device management
└── segment.cpp           ← segment size calculation
```

## 2.7 `src/io/`

**[Decision]**:

```
src/io/
├── csv_export.cpp        ← same as v7 output
└── (json_export.cpp)     ← later
```

## 2.8 C ABI Headers

**[Decision]**:

```
include/voss/
├── voss.h                ← general C ABI
├── voss.hpp              ← C++ wrapper
└── voss_primes.h         ← C ABI for primes section
```

## 2.9 Python Bindings

**[Decision]**:

```
bindings/
├── python/
│   └── voss/
│       ├── __init__.py
│       ├── _capi.py      ← ctypes
│       ├── primes.py     ← clean API
│       └── exceptions.py
```

## 2.10 Build

**[Decision]**: CMake for C/C++/CUDA, scikit-build-core for Python.

## 2.11 Preserving v7-golden

**[Decision]**:
- `src/voss_w30_v7.cu` stays as is
- `library/` is new, doesn't touch it
- We copy kernels, not rewrite them

## 2.12 Not Building Now

**[Decision]**: No advanced C API, no Rust/Julia, no JSON, no Web API, no Docker.

---

# Section 3: API Design

## 3.1 Overview

**[Decision]** — two categories:

**Category A — heavy, need handle**: twins, cousin, sexy

**Category B — light, direct functions**: range, nth, next/prev

## 3.2 Handle — Signatures

**[Decision]**:

```c
int voss_primes_ctx_new(
    uint64_t N,
    int profile,
    voss_primes_ctx** out_ctx
);

void voss_primes_ctx_free(voss_primes_ctx* ctx);

int voss_primes_ctx_prime_count(voss_primes_ctx* ctx, uint64_t* out);
int voss_primes_ctx_twins(voss_primes_ctx* ctx, uint64_t* out);
int voss_primes_ctx_cousin(voss_primes_ctx* ctx, uint64_t* out);
int voss_primes_ctx_sexy(voss_primes_ctx* ctx, uint64_t* out);

int voss_primes_ctx_set_segment_size(voss_primes_ctx* ctx, uint64_t seg_size);
int voss_primes_ctx_set_memory_limit(voss_primes_ctx* ctx, uint64_t bytes);
```

## 3.3 Direct Functions

**[Decision]**:

```c
// Prime count — no handle needed (for M0)
int voss_primes_prime_count(uint64_t N, uint64_t* out);

// Primes in range — with default limit
int voss_primes_in_range(
    uint64_t a, uint64_t b,
    uint64_t** out_array, uint64_t* out_count
);

// Primes in range — with custom limit
int voss_primes_in_range_with_limit(
    uint64_t a, uint64_t b, uint64_t max_count,
    uint64_t** out_array, uint64_t* out_count
);

// Nth prime
int voss_primes_nth(uint64_t n, uint64_t* out_prime);

// Next prime
int voss_primes_next(uint64_t x, uint64_t* out_prime);

// Previous prime
int voss_primes_prev(uint64_t x, uint64_t* out_prime);

// Free allocated memory
void voss_free(void* ptr);
```

**Default limit for `voss_primes_in_range`**: 10⁹.

## 3.4 Types

**[Decision]**:

| Type | Size | Usage |
|------|------|-------|
| `uint64_t` | 8 bytes | N, count results |
| `int` | 4 bytes | return code |
| `voss_primes_ctx*` | pointer | handle |

**Reason**: π(10¹³) > 2³².

## 3.5 Profiles

**[Decision]**:

```c
#define VOSS_PROFILE_MINIMAL   0   // π(N) only
#define VOSS_PROFILE_STANDARD  1   // + gaps + chebyshev
#define VOSS_PROFILE_FULL      2   // + statistics + large gaps + CSV
```

## 3.6 Error Codes

**[Decision]**:

```c
#define VOSS_OK                     0
#define VOSS_ERR_INVALID_N          1
#define VOSS_ERR_OUT_OF_RANGE       2
#define VOSS_ERR_NO_CUDA            3
#define VOSS_ERR_OUT_OF_MEMORY      4
#define VOSS_ERR_CUDA               5
#define VOSS_ERR_INVALID_ARG        6
#define VOSS_ERR_INTERNAL           7

const char* voss_strerror(int code);
const char* voss_get_last_error(void);
```

## 3.7 Progress Reporting

**[Decision]**:

```c
typedef void (*voss_progress_cb)(
    uint64_t seg_done, uint64_t seg_total, void* user_data
);

int voss_primes_ctx_set_progress_cb(
    voss_primes_ctx* ctx, voss_progress_cb cb, void* user_data
);

int voss_primes_ctx_progress(
    voss_primes_ctx* ctx,
    uint64_t* out_seg_done, uint64_t* out_seg_total
);
```

## 3.8 C++ Wrapper

**[Decision]**:

```cpp
namespace voss {
    class PrimesContext {
    public:
        explicit PrimesContext(uint64_t N,
                               Profile p = Profile::Standard);
        ~PrimesContext();
        uint64_t prime_count();
        uint64_t twins();
        uint64_t cousin();
        uint64_t sexy();
    };

    uint64_t nth_prime(uint64_t n);
    uint64_t next_prime(uint64_t x);
    uint64_t prev_prime(uint64_t x);
    std::vector<uint64_t> primes_in_range(uint64_t a, uint64_t b);
}
```

## 3.9 Python API

**[Decision]**:

```python
import voss

with voss.primes.Context(10**9, profile="standard") as ctx:
    pi = ctx.prime_count()
    twins = ctx.twins()
    cousins = ctx.cousin()
    sexy = ctx.sexy()

primes = voss.primes.in_range(10**9, 10**9 + 10000)
p_1000 = voss.primes.nth(1000)
p_next = voss.primes.next(10**9)
p_prev = voss.primes.prev(10**9)
```

---

# Section 4: Behaviors

## 4.1 Handle Lifecycle

**[Decision]**: Create → multiple queries → destroy

- Create: validates, allocates, does not compute
- Queries: computed on demand (lazy)
- Destroy: frees everything

## 4.2 Automatic vs Manual

**[Decision]**:
- Automatic: `SEG_NUM` computed from `cudaMemGetInfo()`
- Manual: `voss_primes_ctx_set_segment_size`, `voss_primes_ctx_set_memory_limit`
- Called before first query

## 4.3 Error Handling

**[Decision]**:
- Every function returns `int`
- `VOSS_OK` = success
- `voss_get_last_error()` = detailed message
- Handle remains valid after failure
- No `exit()`, no `abort()`

## 4.4 Progress Reporting

**[Decision]**:
- Callback: from same thread
- Polling: safe from any thread
- Default: no calls, no cost

## 4.5 Thread Safety

**[Decision]**:

| Scenario | Allowed? |
|----------|----------|
| Two threads, different handles | ✅ |
| Two threads, same handle | ❌ |
| Polling from another thread | ✅ |

- Debug: `assert()`
- Release: undefined behavior (as in CUDA)

## 4.6 Limits

**[Decision]**:

| Profile | Max N |
|---------|-------|
| MINIMAL | 10¹⁴ |
| STANDARD | 10¹³ |
| FULL | 10¹³ |

## 4.7 Profiles — Details

**[Decision]**:

| Feature | MINIMAL | STANDARD | FULL |
|---------|---------|----------|------|
| π(N) | ✅ | ✅ | ✅ |
| Twins/Cousin/Sexy | ✅ | ✅ | ✅ |
| Gap histogram | ❌ | ✅ | ✅ |
| Chebyshev | ❌ | ✅ | ✅ |
| Statistics | ❌ | ❌ | ✅ |
| Large gaps | ❌ | ❌ | ✅ |
| CSV export | ❌ | ❌ | ✅ |

Default: STANDARD.

## 4.8 Memory — Freeing

**[Decision]**:

| Resource | Freed by |
|----------|----------|
| ctx | `voss_primes_ctx_free` |
| primes_in_range array | `voss_free` |
| Progress user_data | User |

- `free(NULL)` is safe
- Double free: undefined

## 4.9 Error Messages

**[Decision]**:
- `voss_strerror`: short English
- `voss_get_last_error`: detailed English
- No translation — library is English-only

## 4.10 Upgrade Behavior

**[Decision]**:
- C ABI stable within 1.x
- C++ API stable within same major
- Python API stable within same major
- Deprecation: warning in 1.x → removal in 2.0

## 4.11 License — BSL

**[Decision]**:
- One-time message at startup (optional)
- After 4 years: automatic Apache-2.0

## 4.12 Git

**[Decision]**:
- Monorepo: `voss`
- Branch: `main`
- Tags on Git
- Source on GitHub, wheels on PyPI

---

# Section 5: Licensing and Distribution

## 5.1 License

**[Decision]**:
- BSL-1.1 (SPDX: `BUSL-1.1`)
- Converts to Apache-2.0 after 4 years
- Source-available, non-commercial for 4 years

**Files**:
- `LICENSE` — BSL-1.1 text
- `LICENSE-APACHE` — Apache-2.0 text (for future conversion)

## 5.2 What BSL-1.1 Allows

**Allowed**: reading, modifying, academic, research, personal use

**Not allowed**: commercial without license, selling services

**After 4 years**: everything allowed under Apache-2.0

## 5.3 Data — Different License

**[Decision]**: Data under CC-BY-4.0

- `results/*.txt` → CC-BY-4.0
- `results/*.csv` → CC-BY-4.0
- `paper/*.tex`, `paper/*.pdf` → CC-BY-4.0

## 5.4 Monorepo Structure

**[Decision]**:

```
voss/
├── README.md
├── LICENSE                  ← BSL-1.1
├── LICENSE-APACHE
├── LICENSE-DATA             ← CC-BY-4.0
├── CITATION.cff
├── CONTRIBUTING.md
├── SECURITY.md
├── GOVERNANCE.md
├── src/                     ← v7-golden
│   └── voss_w30_v7.cu
├── library/                 ← new library
├── paper/                   ← paper (moved)
├── results/
├── scripts/
└── docs/
```

## 5.5 Distribution Channels

**[Decision]**:

| Channel | Content | License |
|---------|---------|---------|
| GitHub | Full source | BSL-1.1 |
| PyPI | Python wheel (binary) | BSL-1.1 |
| arXiv | Paper | CC-BY-4.0 |
| Zenodo | Snapshot | Per file |

**Order**: GitHub → Zenodo → arXiv → PyPI

## 5.6 Package Name

**[Decision]**:
- PyPI: `voss` (reserved on PyPI as of this release)
- Python import: `voss`
- Extras: `voss[numbers]`, `voss[math]` later

**Status**: `voss` placeholder published as v0.0.1.

## 5.7 Hardware Support — Tiered

**[Decision]**:

**Tier 1 — guaranteed (v0.x)**: A100 (sm_80), T4 (sm_75)

**Tier 2 — deferred to v1.x**: H100 (sm_90), L4/G4 (sm_89)

**Tier 3 — future**: RTX 40xx/50xx, H200, B100

**In v0.x**: only Tier 1 officially supported. Tier 2 "may work, untested".

## 5.8 Versioning

**[Decision]**:
- SemVer: `major.minor.patch`
- `1.0.0` for first stable release
- `0.x.y` before that
- Deprecation: `1.x` warning → `2.0` removal

## 5.9 CITATION

**[Decision]**: `CITATION.cff` contains:
- Name, title, year
- DOI after Zenodo
- GitHub link

## 5.10 README

**[Decision]** — structure:
1. VOSS in one paragraph
2. Performance (key numbers)
3. Installation
4. Quick example (5 lines)
5. Requirements
6. License
7. Links

**Length**: one page.

## 5.11 Documentation

**[Decision]**:

| Document | Location |
|----------|----------|
| README | GitHub (visible) |
| DESIGN.md | `library/docs/` |
| API Reference | `library/docs/api/` |
| Tutorials | `library/docs/tutorials/` |
| methodology.md | `docs/` |
| performance.md | `docs/` |
| Paper | `paper/` |

## 5.12 What We Don't Publish

**[Decision]**: No CUDA source on PyPI, no wheels except Tier 1, no digital signatures, no Docker, no conda-forge in first round.

**[Decision]**: The `publish/` directory is a local PyPI build workspace. It is NOT tracked in git and is listed in `.gitignore`.

## 5.13 Transition to Apache-2.0

**[Decision]**:
- 4 years after first PyPI release
- `LICENSE` replaced
- `LICENSE-APACHE` removed
- `2.0.0` release announces transition
- Old versions keep BSL forever

---

# Section 6: Roadmap

## 6.1 First Milestone (M0)

**[Decision]**: `voss_primes_prime_count(N)`

**Duration**: 2-3 weeks

**Completion criteria**:
- Works on Colab A100
- Tested against 4 sources
- `pip install` from GitHub
- CI passes

**Includes**: `library/` structure, C ABI + C++ + Python, two kernels (`sieve_w30_seg_kernel`, `extract_w30_seg_kernel`), basic tests.

**Excludes**: handle, profiles, six functions, CSV, progress, threading.

## 6.2 Six Phases

**[Decision]**:

| Phase | Duration | Output |
|-------|----------|--------|
| M0 | 2-3 weeks | `prime_count(N)` |
| M1 | 2 weeks | handle + profiles |
| M2 | 3 weeks | twins, cousin, sexy |
| M3 | 2 weeks | range, nth, next/prev |
| M4 | 2 weeks | statistics + CSV + large gaps |
| M5.0 | 2 weeks | comprehensive tests + CI + docs |
| M5.1 | 1 week | is_prime + Sophie Germain |
| M5.2 | 1 week | Factorization (Pollard rho) |
| M5.3 | 1 week | Mersenne + Fermat |
| M5.4 | 1 week | Goldbach partitions |

**Total**: 18-20 weeks (~4.5-5 months) until `v0.5.0`.

**Note**: M5 was originally scoped as a single phase. It was expanded on
2026-09-30 to include the 6 remaining primes-section functions (Group A).
Each sub-phase ships as a patch release (v0.4.1, v0.4.2, ...) before the
next begins.

## 6.3 M0 — Details

**Week 1**: structure
**Week 2**: bindings
**Week 3**: tests and release

**Success criterion**:
```python
import voss
assert voss.primes.prime_count(10**9) == 50_847_534
```

## 6.4 M1 — Handle + Profiles

```python
with voss.primes.Context(10**9, profile="standard") as ctx:
    pi = ctx.prime_count()
```

## 6.5 M2 — Twins, Cousin, Sexy

```python
with voss.primes.Context(10**9, profile="standard") as ctx:
    assert ctx.twins() == 3_424_506
    assert ctx.cousin() == 3_424_679
    assert ctx.sexy() == 6_089_791
```

## 6.6 M3 — Range, Nth, Next/Prev

```python
primes = voss.primes.in_range(10**9, 10**9 + 10**6)
assert voss.primes.nth(1000) == 7919
assert voss.primes.next(10**9) == 1_000_000_007
assert voss.primes.prev(10**9) == 999_999_937
```

## 6.7 M4 — Statistics + CSV + Large Gaps

- `profile="full"` runs everything
- CSV identical to v7-golden
- Comparison test against v7

## 6.8 M5 — Comprehensive Tests

- 8 verification levels
- Reference implementation in Python
- Edge cases
- Stress tests
- **MINIMAL at 10¹⁴**: single-segment test (~10 seconds) to verify code doesn't crash
- Publish `v0.5.0`

## 6.9 After M5

- After v0.5.0: 6 months dogfooding
- After 6 months: v1.0.0
- After 1 year: begin general numbers section

## 6.10 Not Building

**[Decision]**: No ML before v1.0.0, no Cloud API, no Rust/Julia, no Web, no mobile, no Windows in v0.x.

## 6.11 Decision Gates

**[Decision]**:

| Gate | After | Go criterion |
|------|-------|--------------|
| G0 | M0 | π(10⁹) passes |
| G1 | M1 | handle no leaks |
| G2 | M2 | twins matches files |
| G3 | M3 | sympy/primesieve match |
| G4 | M4 | FULL matches v7 exactly |
| G5 | M5 | CI + PyPI |

## 6.12 Risks

**Technical**: ctypes on Colab, CMake + CUDA

**Schedule**: 3.5 months may become 6 months

**Commitment**: loss of motivation → M0 gives early victory

**Scope**: unplanned expansion → DESIGN.md prevents

## 6.13 After 12 Months

**Expected**: v1.0.0, 500-2000 users, updated arXiv paper, start of general numbers section

**Not expected**: ML, Cloud API, large community, funding

---

---

## 6.14 Conjecture Testing (v0.6+, primes section)

**[Decision]**: VOSS provides **empirical tests** of well-known
conjectures up to a user-supplied N. Tests are **NOT proofs**.

**Naming convention**: `test_<conjecture>_upto(N)`.
**Docstring must state**: "Empirical test up to N. Does NOT prove the conjecture."

**In scope (v0.6+)** — use existing functions, no new kernel:
- Bertrand: prime in (n, 2n) for all n in [2, N]
- Legendre: prime in (n², (n+1)²) for all n in [1, √N]
- Goldbach: even n ≥ 4 = sum of two primes, for all even n in [4, N]
- Chebyshev bias: π(N; 4,3) > π(N; 4,1) up to N

**Deferred (v0.7+)** — require new kernel:
- Cramér: g_n ≤ (log p_n)²
- Polignac: for every even k, at least one prime gap = k appears
- Hardy-Littlewood constants

**Out of scope**:
- Conjecture discovery / statistical inference
- Prime prediction (see 6.10: no ML before v1.0.0)
## Changelog

- **2026-09-30** — Added 6.14 Conjecture Testing (v0.6+, primes section). Empirical tests only, no proofs.
- **2026-09-30** — M5 expanded into M5.0-M5.4 to include Group A functions
  (is_prime, Sophie Germain, Factorization, Mersenne, Fermat, Goldbach).
  Total v0.5.0 timeline: 13-15 weeks → 18-20 weeks.

---

# End of DESIGN.md

---
