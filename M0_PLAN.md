# M0_PLAN.md — Content

**انسخ كل ما يلي والصقه في GitHub كملف `M0_PLAN.md`**

---

```markdown
# M0 — Detailed Plan

**Goal**: `voss_primes_prime_count(N)` working end-to-end.
**Duration**: 3 weeks (21 days).
**Success criterion**: `assert voss.primes.prime_count(10**9) == 50_847_534`

---

## Environment Notes

- Working environment: Google Colab
- GPU: A100 (Tier 1)
- CUDA available: yes
- Source code reference: `voss_w30_v7.cu` (in `src/`)
- Target repo: `github.com/atafhamada/voss`

All work happens in a fresh Colab notebook, pushed to GitHub via browser (upload) or Colab's git integration.

---

## Week 1 — Structure

### Day 1 — Directory Skeleton

Create locally (in Colab), then push:

```
library/
├── include/voss/
│   ├── voss.h
│   └── voss_primes.h
├── src/
│   ├── core/
│   │   ├── error.cpp
│   │   ├── error.hpp (internal)
│   │   ├── cuda_context.cpp
│   │   └── memory.cpp
│   └── primes/
│       ├── prime_count.cpp
│       ├── sieve.cu
│       └── extract.cu
├── tests/
└── CMakeLists.txt
```

**Deliverable**: empty structure committed to GitHub.

### Day 2 — CMake Skeleton

`CMakeLists.txt`:
- Project name: `voss_core`
- CUDA language enabled
- Architectures: `sm_75;sm_80`
- Builds `libvoss_core.a` (static library)
- Builds `test_prime_count` binary

**Deliverable**: `cmake -B build && cmake --build build` runs (no source yet → no error).

### Day 3 — Copy Kernels from v7-golden

From `voss_w30_v7.cu`:
- `sieve_w30_seg_kernel` (lines ~30-52)
- `extract_w30_seg_kernel` (lines ~54-78)
- `generate_base_primes` (lines ~30-50)
- `modinv` (lines ~52-64)

**Action**:
- Copy `sieve_w30_seg_kernel` → `library/src/primes/sieve.cu`
- Copy `extract_w30_seg_kernel` → `library/src/primes/extract.cu`
- Copy `generate_base_primes` + `modinv` → `library/src/primes/prime_count.cpp` (or split into `core/`)
- **Do not modify kernels yet** — copy as-is

**Deliverable**: files copied, no builds yet.

### Day 4 — Adapt Kernels to Library Context

**Changes needed**:
- Remove `main()` dependencies
- Make `sieve_w30_seg_kernel` + `extract_w30_seg_kernel` callable from C++
- Keep signatures identical (they're already `__global__ void`)

**Verification**: compile `sieve.cu` + `extract.cu` with `nvcc -c` → no errors.

**Deliverable**: kernels compile standalone.

### Day 5 — Error Handling Foundation

`library/src/core/error.cpp`:
- Return codes: `VOSS_OK`, `VOSS_ERR_*` (from DESIGN.md 3.6)
- Global error message: `voss_get_last_error()`
- `voss_strerror(int)` maps code → short string

**Deliverable**: `error.cpp` compiles, `voss_strerror(0)` returns `"OK"`.

### Day 6-7 — Implement `voss_primes_prime_count`

From `voss_w30_v7.cu`: extract the `main()` loop logic that:
1. Generates base primes
2. Loops over segments
3. Sieves each segment
4. Extracts and counts
5. Returns total

**Convert to**:
```c
int voss_primes_prime_count(uint64_t N, uint64_t* out);
```

**Simplification for M0**:
- Skip gap computation (not needed for count)
- Skip Chebyshev (not needed for count)
- Skip CSV export
- Skip large gaps

**Verification**: standalone C++ test program calls the function with `N=10**9` → prints `50847534`.

**Deliverable**: `prime_count` returns correct value for 10⁹.

---

## Week 2 — Bindings

### Day 8-9 — C ABI Header

`library/include/voss/voss.h`:
- Error codes
- `voss_strerror`, `voss_get_last_error`

`library/include/voss/voss_primes.h`:
- `voss_primes_prime_count(uint64_t N, uint64_t* out)`

**Deliverable**: headers compile, symbols exported in `libvoss_core.a`.

### Day 10-11 — Python ctypes Wrapper

`library/bindings/python/voss/_capi.py`:
- Load `libvoss_core.so`
- Declare function signatures via `ctypes`

`library/bindings/python/voss/primes.py`:
```python
def prime_count(N: int) -> int:
    out = ctypes.c_uint64()
    rc = _lib.voss_primes_prime_count(N, ctypes.byref(out))
    if rc != 0:
        raise VossError(_lib.voss_get_last_error())
    return out.value
```

`library/bindings/python/voss/exceptions.py`:
- `VossError` (base)
- Map error codes → specific exceptions later

**Deliverable**: `import voss; voss.primes.prime_count(10**9)` works in Colab.

### Day 12 — Python Packaging

`library/pyproject.toml`:
- Use `scikit-build-core`
- Project name: `voss` (local version, not PyPI yet)
- Include C++ and CUDA sources

**Deliverable**: `pip install -e library/` succeeds.

### Day 13-14 — End-to-End Test

Run in Colab:
```python
import voss
assert voss.primes.prime_count(10**9) == 50_847_534
```

Test other values:
```python
assert voss.primes.prime_count(10**6) == 78_498
assert voss.primes.prime_count(10**7) == 664_579
assert voss.primes.prime_count(10**8) == 5_761_455
```

**Verification source**: from `compare_with_primesieve.py` (expected values).

**Deliverable**: M0 success criterion achieved.

---

## Week 3 — Tests and Release

### Day 15-16 — C++ Unit Tests

Using Catch2 or GoogleTest:
- Test `voss_strerror(0) == "OK"`
- Test `voss_primes_prime_count(2)` → 1
- Test `voss_primes_prime_count(10)` → 4
- Test `voss_primes_prime_count(10**6)` → 78,498
- Test invalid: `voss_primes_prime_count(0)` → `VOSS_ERR_INVALID_N`

**Deliverable**: `ctest` passes all tests.

### Day 17-18 — Python Tests

`library/tests/test_primes.py` (pytest):
- Same cases as C++ tests
- Plus: verify against `sympy.primepi` for small N
- Plus: verify against values from `results/` files

**Verification sources**:
- sympy (small N)
- primesieve (medium N)
- OEIS A006880 (via stored values)

**Deliverable**: `pytest` passes all tests.

### Day 19 — CI

GitHub Actions workflow:
- Ubuntu 22.04 + CUDA 12.4
- Build library
- Run C++ tests
- Run Python tests (CPU-only for now — GPU tests deferred)

**Deliverable**: CI passes on push.

### Day 20 — README + Docs

Update root `README.md`:
- Add "Library" section
- Show `pip install git+https://github.com/atafhamada/voss`
- Show 5-line example

Add `library/docs/api/README.md`:
- Document `voss.primes.prime_count`

**Deliverable**: README links to working code.

### Day 21 — Tag v0.1.0

- `git tag v0.1.0`
- `git push --tags`
- Verify `pip install git+https://github.com/atafhamada/voss@v0.1.0`

**Deliverable**: v0.1.0 installable from GitHub.

---

## Decision Gates During M0

- **G0**: after Day 7 → π(10⁹) correct locally
- **G5** (early version): after Day 21 → CI + install from GitHub

**If G0 fails**: stop, debug kernels. Do not proceed to Week 2.

---

## Deliverables Summary

**End of Week 1**: `libvoss_core.a` compiles, `prime_count(10**9)` returns 50,847,534 in C++.

**End of Week 2**: `import voss; voss.primes.prime_count(10**9)` works in Python.

**End of Week 3**: tagged `v0.1.0`, installable via `pip install` from GitHub, CI green.

---

## What M0 Does NOT Include

- No handle (`voss_primes_ctx_*`)
- No profiles
- No twins/cousin/sexy
- No range/nth/next/prev
- No CSV export
- No progress callbacks
- No thread safety
- No error recovery beyond basics
- No automatic segment size (uses fixed `SEG_NUM` from v7)

---

## Notes on Colab Constraints

- **Session limit**: Colab free tier ~12 hours max, but GPU may disconnect earlier
- **Working strategy**: commit often — after each day's deliverable
- **Persistence**: use `git push` after every meaningful change
- **Backup**: clone repo into Colab at start of each session: `!git clone https://github.com/atafhamada/voss.git`

---

## References

- `DESIGN.md` — official design document
- `src/voss_w30_v7.cu` — reference implementation (do not modify)
- `results/*.txt` — verification data (10⁹ to 10¹³)
```

---
