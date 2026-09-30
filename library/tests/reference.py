"""
reference.py — Slow, independent reference implementation.

No GPU, no VOSS internals. Uses sympy for prime generation.
Purpose: cross-check VOSS results against an independent source.
"""

import sympy
from typing import Dict, List


def primes_up_to(N: int) -> List[int]:
    """List of primes <= N, ascending."""
    if N < 2:
        return []
    return [int(p) for p in sympy.primerange(2, N + 1)]


def prime_count(N: int) -> int:
    """pi(N): number of primes <= N."""
    return int(sympy.primepi(N))


def gap_counts(N: int) -> Dict[int, int]:
    """Return dict {gap_size: count} for gaps between consecutive primes <= N."""
    ps = primes_up_to(N)
    counts = {}
    for i in range(len(ps) - 1):
        g = ps[i+1] - ps[i]
        counts[g] = counts.get(g, 0) + 1
    return counts


def twins(N: int) -> int:
    return gap_counts(N).get(2, 0)


def cousin(N: int) -> int:
    return gap_counts(N).get(4, 0)


def sexy(N: int) -> int:
    return gap_counts(N).get(6, 0)


def chebyshev_bias(N: int) -> tuple:
    """Return (pi_4_1, pi_4_3) — counts of primes <= N in residues 1 and 3 mod 4."""
    ps = primes_up_to(N)
    c1 = sum(1 for p in ps if p % 4 == 1)
    c3 = sum(1 for p in ps if p % 4 == 3)
    return c1, c3


def statistics(N: int) -> dict:
    """Compute mean, std, skewness, kurtosis of gap distribution."""
    import math
    counts = gap_counts(N)
    total = sum(counts.values())
    if total == 0:
        return {"total": 0, "mean": 0.0, "std": 0.0, "skew": 0.0, "kurt": 0.0}
    weighted = sum(g * c for g, c in counts.items())
    mean = weighted / total
    var_sum = sum(c * (g - mean) ** 2 for g, c in counts.items())
    var = var_sum / total
    std = math.sqrt(var)
    m3 = sum(c * (g - mean) ** 3 for g, c in counts.items()) / total
    m4 = sum(c * (g - mean) ** 4 for g, c in counts.items()) / total
    skew = m3 / (var * std) if var > 0 and std > 0 else 0.0
    kurt = m4 / (var * var) - 3.0 if var > 0 else 0.0
    return {"total": total, "mean": mean, "std": std, "skew": skew, "kurt": kurt}
