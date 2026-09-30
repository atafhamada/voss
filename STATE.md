# VOSS — Project State

**Last updated**: 2026-09-30
**Current milestone**: M2 (in progress)
**Last stable release**: v0.2.0 (M1)

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

Run Cell C - build the project:

```python
import subprocess, os
os.chdir("/content/voss/library")
subprocess.run(["rm", "-rf", "build"])
subprocess.run(["cmake", "-B", "build"])
r = subprocess.run(["cmake", "--build", "build", "-j4"],
                   capture_output=True, text=True)
print(r.stdout[-2000:])
print("STDERR:", r.stderr[-1000:])
print("Exit:", r.returncode)
```

Expected: build success with libvoss.so + libvoss_core.a.

## What comes after Cell C

1. **Cell D**: update Python bindings (_capi.py + primes.py)
   - Add _lib.voss_primes_ctx_twins/cousin/sexy signatures
   - Add Context.twins(), Context.cousin(), Context.sexy() methods
2. **Cell E**: test with libvoss_m2.so (rename to bypass Python .so cache)
   - Expected: twins(10^9) = 3,424,506 / cousin = 3,424,679 / sexy = 6,089,791
3. **Cell F**: pytest - add M2 tests, run full suite (expect ~29 tests)
4. **Cell G**: commit + push + tag v0.3.0

## M2 Cell A + B already done (not yet tested)

Files modified/created:
- library/src/primes/gaps.cu (NEW - copied from v7-golden)
- library/src/primes/context.cu (REWRITTEN - added histogram + twins/cousin/sexy)
- library/include/voss/voss_primes.h (added 3 function declarations)
- library/CMakeLists.txt (added gaps.cu to sources)

## Environment

- Runtime: Google Colab, GPU A100, CUDA 12.8
- Repo: /content/voss
- GitHub token: stored in Colab Secrets as GITHUB_TOKEN
- Build dir: /content/voss/library/build
- Python bindings path: /content/voss/library/bindings/python

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

**Not yet tested**: N > 10^9 (multi-segment), thread safety, CUDA memcheck.

## Milestones remaining

- M2: twins, cousin, sexy (in progress)
- M3: range, nth, next/prev
- M4: statistics + CSV + large gaps
- M5.0: comprehensive tests + CI + docs -> v0.5.0
- M5.1: is_prime + Sophie Germain
- M5.2: Factorization
- M5.3: Mersenne + Fermat
- M5.4: Goldbach

## Critical technical notes

- Python .so cache: after rebuilding libvoss.so, Python keeps the old one loaded.
  Workaround: copy to a new filename (e.g., libvoss_m2.so), set VOSS_LIBRARY_PATH, reload modules.
- Colab kernel restart: if stuck, Runtime -> Restart session (files in /content/ survive).
- max_pos limit: current code uses max_pos = N/2. Works up to ~10^10. Fix planned for M4.
