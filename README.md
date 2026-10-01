# VOSS: Vectorized Odd Segmented Sieve

GPU-accelerated prime gap library.

**Latest release**: v0.7.0

## Quick links

- DESIGN.md — design decisions
- STATE.md — current state & how to resume work
- library/README.md — build & usage
- library/docs/api/ — Python & C API reference
- paper/ — academic paper

## Installation

```bash
pip install voss
```

- PyPI: https://pypi.org/project/voss/
- Binary wheel (Linux x86_64, manylinux). Windows/macOS not supported yet.

> Note: the old `voss-prime-gaps` package on PyPI is deprecated. Use `voss`.
> https://pypi.org/project/voss-prime-gaps/ (deprecated)

## Platform support

| Component | Supported |
|-----------|-----------|
| OS | Linux x86_64 (manylinux_2_17) |
| Python | 3.9+ |
| CUDA | 12.x |
| CMake | 3.22+ (build from source only) |

**GPU tiers** (per `DESIGN.md` 5.7):

| Tier | GPUs | Status |
|------|------|--------|
| Tier 1 | A100 (sm_80), T4 (sm_75) | Officially supported |
| Tier 2 | H100 (sm_90), L4/G4 (sm_89) | May work, untested |
| Tier 3 | RTX 40xx/50xx, H200, B100 | Future |

**Windows and macOS are not supported in v0.x.**

## Status

| Milestone | Version | What |
|-----------|---------|------|
| M0 | v0.1.0 | prime_count |
| M1 | v0.2.0 | Context + profiles |
| M2 | v0.3.0/v0.3.1 | twins, cousin, sexy |
| M3 | v0.4.0 | in_range, nth, next, prev |
| M4 | v0.4.1-v0.4.4 | statistics, chebyshev, large gaps, CSV |
| — | v0.4.5 | dynamic SEG_NUM (24-100x faster small N) |
| M5.0 | v0.5.0 | reference.py, verify script, docs, CI |
| M5.1 | v0.5.1 | is_prime + Sophie Germain |
| M5.2 | v0.5.2 | factorize (Pollard rho + Miller-Rabin) |
| M5.3 | v0.5.3 | Mersenne + Fermat primes |
| M5.4 | v0.5.4 | Goldbach partitions |
| M5.5 | v0.5.5 | help() + CLI + binary wheel on PyPI |
| M5.x | v0.5.6 | repo cleanup after PyPI release |
| M6 | v0.6.0 | `voss.conjectures` (test_* + iter_*) + GPU goldbach up to 10^9 |
| M6.1 | v0.7.0 | `Context.set_progress(callback)` for live progress |

## Verified

- 112 pytest tests pass (82 + 30 conjecture tests)
- CUDA sanitizer: 0 errors
- Cross-checked against sympy at every scale
- Matches v7-golden at 10^9..10^12

## Performance (vs previous Wheel-2 versions)

| N | voss v0.4.5 | v10/v13 | ratio |
|---|-------------|---------|-------|
| 10^9  | 56 ms  | 52.8 ms | ~1.0x |
| 10^10 | 530 ms | 744 ms  | 1.4x faster |
| 10^11 | 5.36 s | 8.24 s  | 1.54x faster |

## Repo layout

    voss/
    ├── DESIGN.md              — design document
    ├── STATE.md               — current state
    ├── src/                   — v7-golden (frozen reference)
    ├── library/               — the library
    │   ├── include/voss/      — public headers
    │   ├── src/               — implementation
    │   ├── bindings/python/   — Python bindings
    │   ├── tests/             — tests + reference
    │   └── docs/              — documentation
    ├── paper/                 — academic paper
    ├── scripts/               — benchmark & analysis
    └── .github/workflows/     — CI

## License

BSL-1.1 (Business Source License). Becomes Apache-2.0 four years after first PyPI release.
