"""VOSS: GPU-accelerated prime gap library."""

from . import primes
from .primes import Context, Statistics, ChebyshevBias, LargeGap
from .exceptions import VossError

__version__ = "0.5.6"

__all__ = ["primes", "Context", "Statistics", "ChebyshevBias", "LargeGap",
           "VossError", "help"]


def help(topic: str = None) -> None:
    """Show VOSS help. Same as running `python -m voss --help`.

    Parameters
    ----------
    topic : str, optional
        If given, show detailed help for that function.
        Example: help("prime_count")

    Examples
    --------
    >>> import voss
    >>> voss.help()                # overview
    >>> voss.help("prime_count")   # detailed help for one function
    """
    if topic is not None:
        obj = getattr(primes, topic, None)
        if obj is None:
            print(f"Unknown topic: {topic!r}")
            print(f"Available: prime_count, in_range, nth, next_prime, "
                  f"prev_prime, is_prime, factorize, goldbach_count, "
                  f"is_mersenne_prime, is_fermat_prime, Context")
            return
        print(f"=== voss.primes.{topic} ===")
        print()
        print(obj.__doc__ or "(no documentation)")
        return

    print(f"VOSS v{__version__} — GPU-accelerated prime gap library")
    print("=" * 60)
    print()
    print("QUICK START")
    print("-" * 60)
    print("  import voss")
    print("  print(voss.primes.prime_count(10**9))   # 50847534")
    print()
    print("CONTEXT (recommended for multiple queries on same N)")
    print("-" * 60)
    print("  with voss.primes.Context(10**9) as ctx:")
    print("      print(ctx.prime_count())    # 50847534")
    print("      print(ctx.twins())          # 3424506")
    print("      print(ctx.statistics().mean_gap)")
    print()
    print("MODULE-LEVEL FUNCTIONS")
    print("-" * 60)
    print("  prime_count(N)      pi(N) — count primes <= N")
    print("  in_range(a, b)      list of primes in [a, b]")
    print("  nth(n)              nth prime (1-indexed)")
    print("  next_prime(x)       smallest prime > x")
    print("  prev_prime(x)       largest prime < x")
    print("  is_prime(x)         primality test")
    print("  factorize(x)        prime factorization")
    print("  goldbach_count(n)   # of Goldbach partitions of even n")
    print("  is_mersenne_prime(p)  is 2^p-1 prime?")
    print("  is_fermat_prime(n)    is 2^(2^n)+1 prime?")
    print()
    print("CONTEXT METHODS (require STANDARD or FULL profile)")
    print("-" * 60)
    print("  prime_count()       pi(N)")
    print("  twins()             # of twin prime pairs")
    print("  cousin()            # of cousin prime pairs")
    print("  sexy()              # of sexy prime pairs")
    print("  statistics()        Statistics object (mean, std, ...)")
    print("  chebyshev()         ChebyshevBias object")
    print("  large_gaps()        list of LargeGap objects")
    print("  sophie_germain()    # of Sophie Germain primes")
    print("  export_csv(prefix)  write results to CSV files")
    print()
    print("PROFILES")
    print("-" * 60)
    print("  minimal    Only prime_count (fastest)")
    print("  standard   All methods except export_csv (DEFAULT)")
    print("  full       Same as standard (large_gaps requires memory)")
    print()
    print("DETAILED HELP")
    print("-" * 60)
    print("  voss.help('prime_count')     # for any function name")
    print("  help(voss.primes.Context)    # Python's built-in help")
    print()
    print("EXAMPLES FOR YOUR ROLE")
    print("-" * 60)
    print("  Student:      run  python -m voss examples")
    print("  Researcher:   see library/docs/getting-started.md")
    print("  Engineer:     see library/docs/api/README.md")
    print()
    print("MORE")
    print("-" * 60)
    print("  python -m voss --help         command-line interface")
    print("  https://github.com/atafhamada/voss")
    print()


# Keep reference for CLI
__primes__ = primes
