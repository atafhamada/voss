# VOSS — Project State

**Last updated**: 2026-09-30
**Current milestone**: M4 complete, M5 not started
**Last stable release**: v0.4.4 (M4)

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

## Where we are

- **M0** done, v0.1.0 - prime_count(N) working end-to-end
- **M1** done, v0.2.0 - Context handle + lazy cache + 3 profiles
- **M2** in progress - twins, cousin, sexy (gap histogram)

## Next step (resume here)

M4 complete at v0.4.4. Next: **M5.0** — comprehensive tests + CI + docs.

### M5.0 plan

1. **CUDA memcheck**: run compute-sanitizer on test_primes
2. **Benchmark suite**: extend `scripts/compare_with_primesieve.py`
3. **Reference implementation** (Python, slow) for cross-checking
4. **CI improvements**: test on T4 + A100 (self-hosted runner if possible)
5. **Documentation**: expand README, add API reference
6. **Tag v0.5.0** when all M5.0 criteria met

### What M4 delivered (recap)

- v0.4.0: 10^9 barrier broken (per-segment buffer)
- v0.4.1: statistics (mean/std/skew/kurtosis)
- v0.4.2: Chebyshev bias (pi_4_1, pi_4_3)
- v0.4.3: large gaps (>= 500)
- v0.4.4: CSV export

pytest: 58 tests passing (excl. slow 10^12 test).

## How to resume in a new chat

1. Open Colab, GPU runtime, run:
```python
from google.colab import userdata
import subprocess, os
token = userdata.get("GITHUB_TOKEN")
os.chdir("/content")
if not os.path.exists("voss"):
    subprocess.run(["git", "clone",
        f"https://x-access-token:{token}@github.com/atafhamada/voss.git"])
os.chdir("/content/voss")
subprocess.run(["git", "config", "user.email", "atafhamada@users.noreply.github.com"])
subprocess.run(["git", "config", "user.name", "Ataf Hamada"])
```
2. Paste the content of this file (STATE.md) into the new chat.
3. Say: "Resume from M2, next step is Cell C."

## Key files

- DESIGN.md - full design (27+ decisions, English)
- M0_PLAN.md - original 21-day plan (reference)
- STATE.md - this file
- library/README.md - build instructions

## Test evidence (as of v0.3.1)

Comprehensive testing has been performed at N = 2..10^9:

- **Stage 1**: N = 101..1000 (900 consecutive values) — all match sympy
- **Stage 2**: 1000 random samples in [2, 10^6] — all match sympy
- **Stage 3**: 29 boundary values (powers, primes, segment boundaries) — all match
- **Stage 4**: 500 sequential Contexts — 0 MB GPU memory leak
- **Stage 5**: Reproduce v0.3.0 crash scenario — no crash
- **Stage 6**: Cross-profile consistency (minimal/standard/full) — all agree

Exhaustive N = 2..100 tested; all values match sympy reference.

**M4 verification** (2026-09-30):
- N = 10^10 (2 segments of 5e10): pi/twins/cousin/sexy match 1e10.txt, 0.54 s
- N = 10^11 (3 segments): pi/twins/cousin/sexy match 1e11.txt, 5.33 s

**Still not tested**: N >= 10^12, thread safety, CUDA memcheck.

## Milestones remaining

- M2: twins, cousin, sexy  [DONE, v0.3.1]
- M3: range, nth, next/prev  [DONE, v0.4.0]
- M4: statistics + CSV + large gaps  [DONE, v0.4.4]
- M5.0: comprehensive tests + CI + docs  [NEXT]
- M5.1: is_prime + Sophie Germain
- M5.2: Factorization
- M5.3: Mersenne + Fermat
- M5.4: Goldbach

## Critical technical notes

- Python .so cache: after rebuilding libvoss.so, Python keeps the old one loaded.
  Workaround: copy to a new filename (e.g., libvoss_m2.so), set VOSS_LIBRARY_PATH, reload modules.
- Colab kernel restart: if stuck, Runtime -> Restart session (files in /content/ survive).
- max_pos limit: current code uses max_pos = N/2. Works up to ~10^10. Fix planned for M4.
