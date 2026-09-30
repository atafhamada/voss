# VOSS Library

**GPU-accelerated prime gap library** (part of VOSS).

## Status

**v0.4.5** — M4 complete + performance fixes.

Implemented: prime_count, Context, twins/cousin/sexy, in_range,
nth, next_prime, prev_prime, statistics, chebyshev, large_gaps, export_csv.

## Requirements

- NVIDIA GPU (Tier 1: A100, T4)
- CUDA 12.x
- Python 3.9+
- CMake 3.22+

## Build

    cd library
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j

## Quick Start (Python)

    import os, sys
    os.environ['VOSS_LIBRARY_PATH'] = '/path/to/library/build/libvoss.so'
    sys.path.insert(0, '/path/to/library/bindings/python')

    import voss

    print(voss.primes.prime_count(10**9))   # 50847534

    with voss.primes.Context(10**9) as ctx:
        print(ctx.prime_count())             # 50847534
        print(ctx.twins())                   # 3424506
        print(ctx.statistics().mean_gap)     # 19.6666
        print(ctx.chebyshev().difference)    # +551

    print(voss.primes.in_range(10, 30))     # [11, 13, ..., 29]
    print(voss.primes.nth(1000))            # 7919
    print(voss.primes.next_prime(10**9))    # 1000000007

## Profiles

| Profile | Computes | Max N |
|---------|----------|-------|
| MINIMAL | prime_count only | 10^14 |
| STANDARD | + histogram + stats + chebyshev + large_gaps | 10^11 (practical) |
| FULL | same as STANDARD | 10^11 (practical) |

## Performance

| N | voss | v10/v13 | ratio |
|---|------|---------|-------|
| 10^9  | 56 ms  | 52.8 ms | ~1.0x |
| 10^10 | 530 ms | 744 ms  | 1.4x faster |
| 10^11 | 5.36 s | 8.24 s  | 1.54x faster |

## Tests

    # C++ (requires GPU)
    cd library/build && ctest --output-on-failure

    # Python (requires GPU)
    pip install -r library/tests/requirements.txt
    pytest library/tests/test_primes.py -v

    # Cross-check
    python library/tests/verify_against_reference.py

    # Benchmark
    python scripts/benchmark.py

    # CUDA sanitizer
    compute-sanitizer --tool memcheck library/build/test_prime_count

## See also

- [../DESIGN.md](../DESIGN.md) — design decisions
- [docs/api/](docs/api/) — Python & C API reference
