# VOSS API Reference (v0.4.5)

## Python module-level functions (voss.primes)

| Function | Returns | Notes |
|----------|---------|-------|
| prime_count(N) | int | M0 direct |
| in_range(a, b) | list[int] | default limit 10^7 primes |
| in_range_with_limit(a, b, max_count) | list[int] | custom limit |
| nth(n) | int | 1-indexed; nth(1)=2 |
| next_prime(x) | int | smallest prime > x |
| prev_prime(x) | int | largest prime < x |

## Context class

voss.primes.Context(N, profile="standard") — context manager.

| Method | Returns | Requires |
|--------|---------|----------|
| prime_count() | int | any profile |
| twins() | int | STANDARD/FULL |
| cousin() | int | STANDARD/FULL |
| sexy() | int | STANDARD/FULL |
| statistics() | Statistics | STANDARD/FULL |
| chebyshev() | ChebyshevBias | STANDARD/FULL |
| large_gaps() | list[LargeGap] | STANDARD/FULL |
| export_csv(prefix) | list[str] | STANDARD/FULL |
| close() | None | — |

## Data classes

- Statistics: mean_gap, std_dev, skewness, kurtosis, total_gaps
- ChebyshevBias: pi_4_1, pi_4_3, difference (property)
- LargeGap: position, gap

## Exceptions

- VossError (base)
  - VossInvalidNError — N < 2 or n < 1
  - VossInvalidArgError — profile mismatch, etc.

## Behavior guarantees

- Caching: each query computed once per Context.
- Profiles: MINIMAL only supports prime_count.
- Thread safety: one Context per thread.
- Memory: Context.__del__ frees GPU resources.

## C ABI

See library/include/voss/voss.h and voss_primes.h.

All functions start with voss_ or voss_primes_.

Error codes: VOSS_OK, VOSS_ERR_INVALID_N, VOSS_ERR_OUT_OF_RANGE,
VOSS_ERR_NO_CUDA, VOSS_ERR_OUT_OF_MEMORY, VOSS_ERR_CUDA,
VOSS_ERR_INVALID_ARG, VOSS_ERR_INTERNAL.

Use voss_strerror(code) for short message; voss_get_last_error() for details.
