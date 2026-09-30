#!/usr/bin/env python3
"""
benchmark.py — VOSS performance across scales.

Requires:
    pip install sympy

Environment:
    VOSS_LIBRARY_PATH must point to libvoss.so
    PYTHONPATH must include library/bindings/python
"""

import os
import sys
import time
from pathlib import Path

# Paths (assume running from repo root)
REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "library" / "bindings" / "python"))

# Allow override
if "VOSS_LIBRARY_PATH" not in os.environ:
    default = REPO / "library" / "build" / "libvoss.so"
    if default.exists():
        os.environ["VOSS_LIBRARY_PATH"] = str(default)
    else:
        print("ERROR: libvoss.so not found. Build first.", file=sys.stderr)
        sys.exit(1)

import voss


# Reference numbers from v7-golden (performance.md)
V7_GOLDEN = {
    10**9:  0.0528,   # seconds, v10 (Wheel-2) at 10^9
    10**10: 0.7439,
    10**11: 8.24,
}


def fmt_time(sec):
    if sec < 1e-3:
        return f"{sec*1e6:>8.1f} µs"
    if sec < 1:
        return f"{sec*1000:>8.2f} ms"
    return f"{sec:>8.2f} s"


def benchmark_scale(N, run_full_pipeline=True):
    """Benchmark one scale. Returns dict with timings."""
    result = {"N": N}

    # Fresh context for accurate timing
    with voss.primes.Context(N, profile="standard") as ctx:
        # 1. Prime count (triggers sieve + extract + gaps + mod4)
        t0 = time.time()
        pi = ctx.prime_count()
        t1 = time.time()
        result["pi"] = pi
        result["prime_count_s"] = t1 - t0

        if run_full_pipeline:
            t0 = time.time()
            tw = ctx.twins()
            co = ctx.cousin()
            sx = ctx.sexy()
            t1 = time.time()
            result["twins"] = tw
            result["cousin"] = co
            result["sexy"] = sx
            result["gaps_cached_s"] = t1 - t0  # should be ~0 (cached)

            t0 = time.time()
            s = ctx.statistics()
            cb = ctx.chebyshev()
            t1 = time.time()
            result["stats_s"] = t1 - t0
            result["mean_gap"] = s.mean_gap
            result["cheb_diff"] = cb.difference

    return result


def main():
    print("=" * 80)
    print("VOSS Benchmark Suite")
    print("=" * 80)
    print()

    scales = [10**6, 10**7, 10**8, 10**9, 10**10, 10**11]
    results = []

    for N in scales:
        print(f"--- N = {N:>15,} ---", flush=True)
        try:
            r = benchmark_scale(N)
            results.append(r)
            print(f"  pi(N)        = {r['pi']:>15,}  ({fmt_time(r['prime_count_s'])})")
            print(f"  twins        = {r['twins']:>15,}  (cached: {fmt_time(r['gaps_cached_s'])})")
            print(f"  cousin       = {r['cousin']:>15,}")
            print(f"  sexy         = {r['sexy']:>15,}")
            print(f"  stats        = {fmt_time(r['stats_s'])}")
            print(f"  mean_gap     = {r['mean_gap']:>15.4f}")
            print(f"  cheb_diff    = {r['cheb_diff']:>+15,}")

            # Compare with v7-golden
            if N in V7_GOLDEN:
                v7 = V7_GOLDEN[N]
                ratio = r["prime_count_s"] / v7
                verdict = "faster" if ratio < 1 else "slower"
                print(f"  v7-golden    = {fmt_time(v7)}  → voss is {ratio:.2f}x {verdict}")
            print()
        except Exception as e:
            print(f"  ERROR: {type(e).__name__}: {e}")
            print()

    # Summary table
    print("=" * 80)
    print("Summary")
    print("=" * 80)
    print()
    print(f"{'N':>15} | {'prime_count':>12} | {'v7-golden':>12} | {'ratio':>8}")
    print("-" * 60)
    for r in results:
        N = r["N"]
        pc = fmt_time(r["prime_count_s"]).strip()
        if N in V7_GOLDEN:
            v7 = V7_GOLDEN[N]
            v7s = fmt_time(v7).strip()
            ratio = f"{r['prime_count_s']/v7:.2f}x"
        else:
            v7s = "—"
            ratio = "—"
        print(f"{N:>15,} | {pc:>12} | {v7s:>12} | {ratio:>8}")

    print()
    print("Benchmark complete.")


if __name__ == "__main__":
    main()
