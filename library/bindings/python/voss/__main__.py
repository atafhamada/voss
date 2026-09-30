"""VOSS CLI: `python -m voss <command>`.

Commands:
    --help, -h          Show this help
    version             Show version
    help [topic]        Show VOSS help (same as `voss.help()`)
    examples            Run curated examples
    prime-count N       Quick pi(N) — where N is like 1e9 or 1000000
    info                Show GPU / CUDA information
"""

import argparse
import re
import sys
import time


def parse_n(s):
    """Parse '1e9' or '1000000' or '10**9' into int."""
    s = s.strip().replace("**", "e").replace("^", "e")
    # handle 1e9 style
    m = re.match(r'^([0-9.]+)e([0-9]+)$', s)
    if m:
        return int(float(m.group(1)) * (10 ** int(m.group(2))))
    return int(s)


def cmd_version(_args):
    import voss
    print(f"voss {voss.__version__}")


def cmd_help(args):
    import voss
    voss.help(args.topic if args.topic else None)


def cmd_info(_args):
    import voss
    print(f"voss version: {voss.__version__}")
    print(f"voss module:  {voss.__file__}")
    print()
    try:
        import subprocess
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,driver_version",
             "--format=csv,noheader"],
            capture_output=True, text=True)
        if r.returncode == 0:
            print("GPU:")
            for line in r.stdout.strip().split("\n"):
                print(f"  {line}")
        else:
            print("GPU: nvidia-smi failed")
    except FileNotFoundError:
        print("GPU: nvidia-smi not found (no GPU or drivers not installed)")


def cmd_examples(_args):
    import voss

    print("=" * 60)
    print("VOSS Examples")
    print("=" * 60)
    print()

    print("[1] Basic prime count")
    print("    voss.primes.prime_count(10**6)")
    t0 = time.time()
    result = voss.primes.prime_count(10**6)
    t1 = time.time()
    print(f"    = {result:,}  ({t1-t0:.4f} s)")
    print()

    print("[2] Context (multiple queries, cached)")
    print("    with voss.primes.Context(10**9) as ctx:")
    print("        ctx.prime_count(); ctx.twins(); ctx.cousin()")
    t0 = time.time()
    with voss.primes.Context(10**9) as ctx:
        pi = ctx.prime_count()
        tw = ctx.twins()
        co = ctx.cousin()
    t1 = time.time()
    print(f"    pi(10^9) = {pi:,}")
    print(f"    twins    = {tw:,}")
    print(f"    cousin   = {co:,}")
    print(f"    ({t1-t0:.4f} s total)")
    print()

    print("[3] Statistics")
    print("    with voss.primes.Context(10**7) as ctx:")
    print("        s = ctx.statistics()")
    with voss.primes.Context(10**7) as ctx:
        s = ctx.statistics()
    print(f"    mean_gap = {s.mean_gap:.4f}")
    print(f"    std_dev  = {s.std_dev:.4f}")
    print(f"    skewness = {s.skewness:.4f}")
    print()

    print("[4] Primes in range")
    print("    voss.primes.in_range(10**9, 10**9 + 1000)")
    t0 = time.time()
    primes = voss.primes.in_range(10**9, 10**9 + 1000)
    t1 = time.time()
    print(f"    {len(primes)} primes, first={primes[0]}, last={primes[-1]}"
          f"  ({t1-t0:.4f} s)")
    print()

    print("[5] Prime-specific functions")
    print(f"    nth(1000)                = {voss.primes.nth(1000)}")
    print(f"    next_prime(10**9)        = {voss.primes.next_prime(10**9)}")
    print(f"    prev_prime(10**9)        = {voss.primes.prev_prime(10**9)}")
    print(f"    is_prime(7919)           = {voss.primes.is_prime(7919)}")
    print(f"    is_prime(8000)           = {voss.primes.is_prime(8000)}")
    print()

    print("[6] Factorization")
    print(f"    factorize(600851475143)  = "
          f"{voss.primes.factorize(600851475143)}")
    print()

    print("[7] Chebyshev bias")
    with voss.primes.Context(10**6) as ctx:
        cb = ctx.chebyshev()
    print(f"    pi(10^6; 4, 1) = {cb.pi_4_1:,}")
    print(f"    pi(10^6; 4, 3) = {cb.pi_4_3:,}")
    print(f"    difference     = {cb.difference:+,}")
    print()

    print("[8] Sophie Germain primes")
    with voss.primes.Context(1000) as ctx:
        sg = ctx.sophie_germain()
    print(f"    count(p <= 1000: p and 2p+1 prime) = {sg}")
    print()

    print("[9] Mersenne primes")
    print(f"    is_mersenne_prime(31)  = {voss.primes.is_mersenne_prime(31)}")
    print(f"    is_mersenne_prime(11)  = {voss.primes.is_mersenne_prime(11)}")
    print()

    print("[10] Goldbach partitions")
    parts = voss.primes.goldbach_partitions(10)
    print(f"    partitions(10)         = {parts}")
    print(f"    count(100)             = {voss.primes.goldbach_count(100)}")
    print()
    print("Done.")


def cmd_prime_count(args):
    import voss
    N = parse_n(args.n)
    print(f"Computing pi({N:,})...")
    t0 = time.time()
    result = voss.primes.prime_count(N)
    t1 = time.time()
    print(f"pi({N:,}) = {result:,}  ({t1-t0:.4f} s)")


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    if not argv:
        print(__doc__)
        return 0

    cmd = argv[0]

    if cmd in ("--help", "-h", "help"):
        # `python -m voss help [topic]`
        if len(argv) > 1 and argv[0] == "help":
            import voss
            voss.help(argv[1])
            return 0
        print(__doc__)
        return 0

    if cmd == "version":
        cmd_version(None)
        return 0

    if cmd == "info":
        cmd_info(None)
        return 0

    if cmd == "examples":
        cmd_examples(None)
        return 0

    if cmd == "prime-count":
        if len(argv) < 2:
            print("Usage: python -m voss prime-count N")
            return 2
        class A: pass
        a = A(); a.n = argv[1]
        cmd_prime_count(a)
        return 0

    print(f"Unknown command: {cmd}")
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
