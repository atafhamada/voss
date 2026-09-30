"""
verify_against_reference.py — Cross-check VOSS against reference.py.

Usage:
    python verify_against_reference.py

Requires GPU + built libvoss.so.
"""

import os
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent  # /content/voss
sys.path.insert(0, str(REPO / "library" / "bindings" / "python"))
sys.path.insert(0, str(REPO / "library" / "tests"))

# Set default .so path
if "VOSS_LIBRARY_PATH" not in os.environ:
    default = REPO / "library" / "build" / "libvoss.so"
    if default.exists():
        os.environ["VOSS_LIBRARY_PATH"] = str(default)

import voss
import reference as ref


def fmt(x, w=15):
    return f"{x:>{w},}"


def check(name, voss_val, ref_val):
    ok = voss_val == ref_val
    mark = "OK" if ok else "FAIL"
    print(f"  [{mark}] {name:<20} voss={fmt(voss_val)}  ref={fmt(ref_val)}")
    return ok


def main():
    print("=" * 75)
    print("VOSS vs Reference Cross-Check")
    print("=" * 75)
    print()

    scales = [10**4, 10**5, 10**6, 10**7, 10**8]
    all_ok = True

    for N in scales:
        print(f"--- N = {N:,} ---")

        with voss.primes.Context(N) as ctx:
            voss_pi = ctx.prime_count()
            voss_tw = ctx.twins()
            voss_co = ctx.cousin()
            voss_sx = ctx.sexy()
            voss_cheb = ctx.chebyshev()
            voss_stats = ctx.statistics()

        ref_pi = ref.prime_count(N)
        ref_tw = ref.twins(N)
        ref_co = ref.cousin(N)
        ref_sx = ref.sexy(N)
        ref_c1, ref_c3 = ref.chebyshev_bias(N)
        ref_stats = ref.statistics(N)

        all_ok &= check("pi(N)",           voss_pi, ref_pi)
        all_ok &= check("twins",           voss_tw, ref_tw)
        all_ok &= check("cousin",          voss_co, ref_co)
        all_ok &= check("sexy",            voss_sx, ref_sx)
        all_ok &= check("pi_4_1",          voss_cheb.pi_4_1, ref_c1)
        all_ok &= check("pi_4_3",          voss_cheb.pi_4_3, ref_c3)
        all_ok &= check("total_gaps",      voss_stats.total_gaps, ref_stats["total"])

        # Statistics (floating point — tolerance)
        tol = 1e-4
        mean_ok  = abs(voss_stats.mean_gap - ref_stats["mean"]) < tol
        std_ok   = abs(voss_stats.std_dev  - ref_stats["std"])  < tol
        skew_ok  = abs(voss_stats.skewness - ref_stats["skew"]) < tol
        kurt_ok  = abs(voss_stats.kurtosis - ref_stats["kurt"]) < tol
        for name, ok, vv, rv in [
            ("mean_gap", mean_ok, voss_stats.mean_gap, ref_stats["mean"]),
            ("std_dev",  std_ok,  voss_stats.std_dev,  ref_stats["std"]),
            ("skewness", skew_ok, voss_stats.skewness, ref_stats["skew"]),
            ("kurtosis", kurt_ok, voss_stats.kurtosis, ref_stats["kurt"]),
        ]:
            mark = "OK" if ok else "FAIL"
            print(f"  [{mark}] {name:<20} voss={vv:.6f}  ref={rv:.6f}")
            all_ok &= ok

        print()

    print("=" * 75)
    if all_ok:
        print("RESULT: ALL CHECKS PASSED")
    else:
        print("RESULT: SOME CHECKS FAILED")
        sys.exit(1)
    print("=" * 75)


if __name__ == "__main__":
    main()
