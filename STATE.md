# VOSS - Project State

**Last updated**: 2026-10-01 (sophie_germain GPU)
**Current milestone**: M5.1-GPU complete (sophie_germain GPU, N<=10^9)
**Latest release**: v0.8.0 (published on PyPI as `voss`)

---

## Working with the user

- **Language**: Arabic for conversation, English for code/docs
- **Protocol**:
  1. Every claim about the project must cite a file (or say "no source")
  2. After every question, provide a suggestion (اقتراحي)
  3. One step per response unless the user asks for a plan
  4. Never assume - ask when unsure
  5. Admit errors immediately, revert to last confirmed point
  6. Never advance past a failed gate
- **Style**: honest, direct, no flattery
- **Never**:
  - Print or paste secrets (GitHub token, PyPI token)
  - Modify src/voss_w30_v7.cu (frozen v7-golden)
  - Add functions outside DESIGN.md scope without approval
- **Test environment**: Google Colab (A100), Python 3.13, CUDA 12.8

---

## Repository and links

- **GitHub**: https://github.com/atafhamada/voss
- **PyPI (main)**: https://pypi.org/project/voss/
- **PyPI (deprecated)**: `voss-prime-gaps` — DELETED from PyPI (404)
- **Latest version**: v0.8.0

---

## What was accomplished

### M0 - M4 (early session)
- M0 (v0.1.0): prime_count
- M1 (v0.2.0): Context + profiles
- M2 (v0.3.0, v0.3.1): twins/cousin/sexy
- M3 (v0.4.0): in_range, nth, next_prime, prev_prime
- M4 (v0.4.1-v0.4.5): statistics, chebyshev, large_gaps, CSV, dynamic SEG_NUM

### M5 (late session)
- M5.0 (v0.5.0): reference.py, verify script, docs, CI fix
- M5.1 (v0.5.1): is_prime + Sophie Germain
- M5.2 (v0.5.2): factorize (Pollard rho + Miller-Rabin)
- M5.3 (v0.5.3): Mersenne + Fermat primes
- M5.4 (v0.5.4): Goldbach partitions
- M5.5a (v0.5.4): voss.help() + CLI + getting-started.md
- M5.5b (v0.5.5): PyPI binary wheel published as `voss`
- M5.x (v0.5.6): repo cleanup — publish/ in .gitignore, README install section, DESIGN.md 5.12 note

---

## Current state

### What works
- 82 pytest tests pass (excludes slow 10^12 test)
- CUDA sanitizer: 0 errors on full pipeline
- Cross-check vs reference.py: all values match at 10^4..10^8
- Performance: 24-100x faster on small N (v0.4.5)
- PyPI: voss 0.8.0 live (binary wheel, Linux x86_64)

### Known limitations
- sophie_germain: N <= 10^9 (GPU, ~2.9s on A100-40GB)
- goldbach: n <= 10^9 (GPU, ~2.2s on A100)
- is_mersenne_prime: p <= 63
- is_fermat_prime: n <= 5
- STANDARD/FULL profile: practical N limit 10^11 on Colab A100
- MINIMAL profile: up to 10^14
- Thread safety: one Context per thread
- Windows/macOS: not supported (manylinux wheel only)
- prime_count at 10^12 (measured 2026-09-30, Colab A100):
  VOSS minimal 55.6s / standard 62.3s / sympy 29.3s.
  Root cause: VOSS uses segmented sieve O(N log log N);
  sympy uses Meissel-Lehmer O(N^(2/3)).
  VOSS's edge is gap computation, not single-N prime_count at large N.

---

## Next steps (when ready)

### M5.1-GPU (v0.8.0 — COMPLETED)
- sophie_germain migrated to GPU: N <= 5e7 (CPU sieve) -> 10^9 (GPU)
- New kernel `sophie_germain_upto.cu` (one thread per prime, atomic count)
- New C ABI: `voss_primes_ctx_sophie_germain_upto(ctx, out)` (count only, same semantics)
- Existing `voss_primes_ctx_sophie_germain` now delegates to GPU variant
- Verified N=10^9: 3308859 — matches independent numpy CPU sieve
  (also verified N=100 -> 10, 10^6 -> 7746, 10^8 -> 423140)
- Performance: 2.87s (GPU) vs ~26s (CPU, numpy) at 10^9
- PyPI: voss 0.8.0 (this release)

### M6.1 (v0.7.0 — COMPLETED)
- Context.set_progress(callback) — C ABI + Python wrapper
- C API: `voss_primes_ctx_set_progress(ctx, cb, user)`
- Callback called after each internal segment
- Verified: 200 callbacks for N=10^13 (A100-40GB, 200 segments)
- pi(10^13) = 346,065,536,839 — matches v7 exactly
- Fixed: __version__ was stuck at 0.5.6 (now 0.7.0)
- PyPI: voss 0.7.0 published

### M6 (v0.6.0 — COMPLETED)
- `voss.conjectures` module: 4 test_* + 4 iter_* functions
- GPU kernel `goldbach_upto.cu`: `test_goldbach_upto` up to 10^9
- Verified: goldbach(10^9) = 2.2s on A100, ce=0
- 30/30 tests pass in test_conjectures.py
- Naming: `test_*_upto` (empirical, not proof) per DESIGN.md 6.14

### M5.x follow-ups (v0.5.6 — COMPLETED)
- [DONE] Update README to `pip install voss` (root + library/README.md)
- [DONE] Remove publish/ build artifacts from git (added to .gitignore)
- [DONE] DESIGN.md 5.12 note: publish/ NOT tracked in git
- [DONE] Remove voss-prime-gaps project from PyPI (deleted manually; now 404)

### M6 (future)
- General numbers section (voss-numbers): phi, tau, sigma, mu, GCD/LCM, Fibonacci, factorial
- Math section (voss-math): linear algebra, optimization
- Both deferred until v1.0.0

### v1.0.0 (after dogfooding)
- 6 months of use -> v1.0.0 release

### Long-term
- ML is NOT planned before v1.0.0 (per DESIGN.md 6.10)

---

## File structure
voss/
|-- DESIGN.md - design document
|-- STATE.md - this file
|-- README.md - root overview
|-- src/ - v7-golden reference (frozen)
|-- library/ - the actual library
|  |-- include/voss/ - public headers
|  |-- src/
|  |  |-- core/ - error, alloc, miller_rabin, is_prime
|  |  |-- primes/ - all prime functions
|  |  +-- io/ - csv export
|  |-- bindings/python/ - Python package (voss/)
|  |-- tests/ - pytest + reference.py + verify script
|  +-- docs/ - API + getting-started
|-- paper/ - academic paper
|-- scripts/ - benchmark.py + analysis
|-- publish/ - PyPI publishing (temp, NOT tracked in git)
+-- .github/workflows/ - CI

---

## Core code details

### Key files
- library/src/primes/sieve.cu    - sieve_w30_seg_kernel
- library/src/primes/extract.cu  - extract_w30_seg_kernel
- library/src/primes/gaps.cu     - gaps_w30_seg_kernel
- library/src/primes/chebyshev.cu - mod4_count_kernel
- library/src/primes/context.cu  - Context implementation
- library/src/primes/sophie_germain_upto.cu - sophie_germain_kernel
- library/bindings/python/voss/primes.py - user API
- library/bindings/python/voss/_capi.py  - ctypes loader

### Key constants
- SEG_NUM = min(N, 5e10)  (dynamic since v0.4.5)
- MAX_GAP = 100000
- VOSS_LARGE_GAP_THRESHOLD = 500
- CUDA architectures: sm_75;sm_80

---

## Environment notes

- Colab A100 has ~40 GB usable GPU memory (not 80 GB)
- GitHub token in Colab Secrets as GITHUB_TOKEN
- PyPI token created but not stored
- Build: cd library && cmake -B build && cmake --build build -j4
- Test: VOSS_LIBRARY_PATH=.../libvoss.so pytest library/tests/test_primes.py

### Important gotcha
- After rebuilding libvoss.so, Python keeps old .so cached.
  Copy to a new filename (e.g., libvoss_v2.so) and update VOSS_LIBRARY_PATH.

---

## How to resume in a new chat

Paste this entire STATE.md content in the first message, then say:

    Resume VOSS project. Next task: [whatever you want]

---

## Session summary (this one)

Duration: ~14 hours
Versions released: v0.1.0 -> v0.5.6 (15 on GitHub, 3 on PyPI)
Tests: 82 pytest + 1 CTest + reference.py verification
Bugs fixed: 2 (N<7 crash, apt mirror CI failure)
Performance: 24-100x on small N

Major milestones:
- Complete primes section (11 function groups)
- CUDA sanitizer clean
- Cross-checked against independent implementation
- Published on PyPI
- CLI + help system
- User-facing documentation

---

## Session (2026-10-01)

Focus: sophie_germain GPU migration (M5.1-GPU) -> v0.8.0

- New file: library/src/primes/sophie_germain_upto.cu (kernel only)
- Modified: context.cu (host wrapper + delegate), voss_primes.h (decl), CMakeLists.txt
- Commit: 2d44799 (feat(sophie): GPU migration — N up to 10^9)
- Verified: 10^9 -> 3308859 (GPU, 2.87s), independent CPU numpy agrees
- N limit: 5e7 -> 1e9
- Memory: device allocation ~650MB; A100-40GB safe
- Pending: STATE.md commit, tag v0.8.0, wheel build + PyPI upload
