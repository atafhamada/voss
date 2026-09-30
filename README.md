# VOSS: Vectorized Odd Segmented Sieve

GPU-accelerated prime gap library.

**Latest release**: v0.4.5

## Quick links

- DESIGN.md — design decisions
- STATE.md — current state & how to resume work
- library/README.md — build & usage
- library/docs/api/ — Python & C API reference
- paper/ — academic paper

## Status

| Milestone | Version | What |
|-----------|---------|------|
| M0 | v0.1.0 | prime_count |
| M1 | v0.2.0 | Context + profiles |
| M2 | v0.3.0/v0.3.1 | twins, cousin, sexy |
| M3 | v0.4.0 | in_range, nth, next, prev |
| M4 | v0.4.1-v0.4.4 | statistics, chebyshev, large gaps, CSV |
| — | v0.4.5 | dynamic SEG_NUM (24-100x faster small N) |
| M5 | upcoming | v0.5.0 stable |

## Verified

- 59 pytest tests pass
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
