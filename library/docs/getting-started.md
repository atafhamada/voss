# Getting Started with VOSS

**VOSS** = GPU-accelerated prime gap library for Python and C++.

## What you can do

- Count primes up to 10^11+ in seconds
- Find twin, cousin, and sexy prime pairs
- Analyze gap distributions (mean, std, skewness, kurtosis)
- Compute Chebyshev bias
- Find large gaps (>= 500)
- Range queries: primes in [a, b], nth prime, next/prev prime
- Primality testing, factorization, Goldbach partitions
- Mersenne and Fermat prime tests

## Requirements

- **NVIDIA GPU** (Tier 1: A100 or T4; Tier 2: H100, L4/G4)
- **CUDA Toolkit 12.x**
- **Python 3.9+**
- **CMake 3.22+** (for building from source)

## Installation

### From source (current)

    git clone https://github.com/atafhamada/voss.git
    cd voss/library
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j

Then in Python:

    import os, sys
    os.environ['VOSS_LIBRARY_PATH'] = '/path/to/voss/library/build/libvoss.so'
    sys.path.insert(0, '/path/to/voss/library/bindings/python')
    import voss

### From PyPI (coming soon)

    pip install voss-prime-gaps

## First steps

### 1. Simple prime count

    import voss
    print(voss.primes.prime_count(10**6))
    # 78498

### 2. Multiple queries on the same N

Use `Context` — it caches results, so subsequent queries are instant:

    with voss.primes.Context(10**9) as ctx:
        print(ctx.prime_count())      # 50847534
        print(ctx.twins())            # 3424506
        print(ctx.cousin())           # 3424679
        print(ctx.sexy())             # 6089791

First call triggers the full GPU pipeline (~60 ms at 10^9);
subsequent calls are ~5 µs.

### 3. Statistics

    with voss.primes.Context(10**7) as ctx:
        s = ctx.statistics()
        print(f"mean gap: {s.mean_gap:.4f}")     # 15.0471
        print(f"std dev:  {s.std_dev:.4f}")      # 12.5697
        print(f"skewness: {s.skewness:.4f}")     # 1.8147

### 4. Range queries

    # All primes in [10^9, 10^9 + 1000]
    primes = voss.primes.in_range(10**9, 10**9 + 1000)
    print(len(primes), primes[0], primes[-1])
    # 13 1000000007 1000000989

    # nth prime (1-indexed)
    print(voss.primes.nth(1000))                # 7919

    # next and previous primes
    print(voss.primes.next_prime(10**9))        # 1000000007
    print(voss.primes.prev_prime(10**9))        # 999999937

### 5. Primality and factorization

    print(voss.primes.is_prime(7919))           # True
    print(voss.primes.factorize(600851475143))  # [71, 839, 1471, 6857]

### 6. Chebyshev bias

    with voss.primes.Context(10**6) as ctx:
        cb = ctx.chebyshev()
        print(cb.pi_4_1)      # 39175
        print(cb.pi_4_3)      # 39322
        print(cb.difference)  # +147

## Profiles

Choose the amount of work:

| Profile | Computes | Typical N limit |
|---------|----------|-----------------|
| `minimal` | prime_count only | 10^14 |
| `standard` (default) | + histogram, stats, chebyshev, large_gaps | 10^11 |
| `full` | same as standard | 10^11 |

    with voss.primes.Context(10**12, profile="minimal") as ctx:
        print(ctx.prime_count())     # fast, no gaps

    with voss.primes.Context(10**9, profile="full") as ctx:
        print(ctx.large_gaps())      # all gaps >= 500

## Getting help

- **`voss.help()`** — overview of all functions
- **`voss.help('prime_count')`** — detailed help for one function
- **`python -m voss --help`** — command-line interface
- **`python -m voss examples`** — run curated examples
- **`python -m voss info`** — show GPU info
- **Full API reference**: `library/docs/api/README.md`

## Troubleshooting

**"VOSS_LIBRARY_PATH does not exist"**
Build the library first (see Installation).

**"No CUDA device available"**
VOSS requires an NVIDIA GPU with CUDA support. Check `nvidia-smi`.

**"N exceeds M0 maximum"**
The current implementation supports N up to 10^11 for STANDARD profile.

**"Profile MINIMAL does not compute gap histogram"**
Gap-related methods (`twins`, `statistics`, etc.) require STANDARD
or FULL profile. Change the profile.

## Where to go next

- **Read the design**: `DESIGN.md`
- **See performance numbers**: `library/README.md`
- **Full API**: `library/docs/api/README.md`
- **Source**: https://github.com/atafhamada/voss
