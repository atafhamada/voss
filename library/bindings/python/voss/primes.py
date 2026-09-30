"""VOSS primes — user-facing API.

M0: prime_count(N)
M1: Context class (handle + lazy cache + profile)
"""

import ctypes

from . import _capi
from ._capi import (
    VOSS_OK,
    VOSS_ERR_INVALID_N,
    VOSS_ERR_INVALID_ARG,
    VOSS_PROFILE_MINIMAL,
    VOSS_PROFILE_STANDARD,
    VOSS_PROFILE_FULL,
)
from .exceptions import VossError


# === Exception classes ===
class VossInvalidNError(VossError):
    """Raised when N < 2."""


class VossInvalidArgError(VossError):
    """Raised when an argument is invalid."""


_ERRMAP = {
    VOSS_ERR_INVALID_N: VossInvalidNError,
    VOSS_ERR_INVALID_ARG: VossInvalidArgError,
}

# === Profile name → int ===
_PROFILES = {
    "minimal":  VOSS_PROFILE_MINIMAL,
    "standard": VOSS_PROFILE_STANDARD,
    "full":     VOSS_PROFILE_FULL,
}


# ============================================================
# Direct function (M0)
# ============================================================
def prime_count(N: int) -> int:
    """Count primes <= N.

    Parameters
    ----------
    N : int
        Upper bound (must be >= 2).

    Returns
    -------
    int
        pi(N).

    Examples
    --------
    >>> import voss
    >>> voss.primes.prime_count(10**6)
    78498
    """
    if not isinstance(N, int):
        raise TypeError(f"N must be int, got {type(N).__name__}")
    if N < 2:
        raise VossInvalidNError(f"N must be >= 2, got {N}")

    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_prime_count(
        ctypes.c_uint64(N),
        ctypes.byref(out),
    )
    _capi._check(rc, _ERRMAP)
    return out.value


# ============================================================
# Context (M1) — handle with lazy cache
# ============================================================
class LargeGap:
    """A single large prime gap (>= 500).

    Attributes
    ----------
    position : int
        The second prime of the gap (larger prime).
    gap : int
        Gap size (difference between consecutive primes).
    """
    def __init__(self, position: int, gap: int):
        self.position = position
        self.gap = gap

    def __repr__(self):
        return f"LargeGap(position={self.position:,}, gap={self.gap})"

    def __eq__(self, other):
        if not isinstance(other, LargeGap):
            return NotImplemented
        return self.position == other.position and self.gap == other.gap


class ChebyshevBias:
    """Chebyshev bias result.

    Attributes
    ----------
    pi_4_1 : int
        Number of primes <= N that are == 1 (mod 4)
    pi_4_3 : int
        Number of primes <= N that are == 3 (mod 4)
    """
    def __init__(self, pi_4_1, pi_4_3):
        self.pi_4_1 = pi_4_1
        self.pi_4_3 = pi_4_3

    @property
    def difference(self) -> int:
        """pi_4_3 - pi_4_1 (typically positive)."""
        return self.pi_4_3 - self.pi_4_1

    def __repr__(self):
        return (f"ChebyshevBias(pi_4_1={self.pi_4_1:,}, "
                f"pi_4_3={self.pi_4_3:,}, "
                f"difference={self.difference:+,})")


class Statistics:
    """Gap distribution statistics (from histogram).

    Attributes
    ----------
    mean_gap : float
    std_dev : float
    skewness : float
    kurtosis : float (excess)
    total_gaps : int
    """
    def __init__(self, mean_gap, std_dev, skewness, kurtosis, total_gaps):
        self.mean_gap   = mean_gap
        self.std_dev    = std_dev
        self.skewness   = skewness
        self.kurtosis   = kurtosis
        self.total_gaps = total_gaps

    def __repr__(self):
        return (f"Statistics(mean_gap={self.mean_gap:.4f}, "
                f"std_dev={self.std_dev:.4f}, "
                f"skewness={self.skewness:.4f}, "
                f"kurtosis={self.kurtosis:.4f}, "
                f"total_gaps={self.total_gaps})")


class Context:
    """Reusable context for multiple queries on the same N.

    The context holds the value of N and a computation profile.
    Results are cached: the first call to `prime_count()` triggers
    the GPU computation; subsequent calls return the cache.

    Parameters
    ----------
    N : int
        Upper bound (must be >= 2).
    profile : str or int, optional
        One of "minimal", "standard", "full" (default "standard").
        (Only `prime_count` is implemented in M1 — profile is
        stored for M2+.)

    Examples
    --------
    >>> import voss
    >>> with voss.primes.Context(10**9) as ctx:
    ...     print(ctx.prime_count())
    50847534
    """

    def __init__(self, N: int, profile="standard"):
        if not isinstance(N, int):
            raise TypeError(f"N must be int, got {type(N).__name__}")
        if N < 2:
            raise VossInvalidNError(f"N must be >= 2, got {N}")

        if isinstance(profile, str):
            if profile not in _PROFILES:
                raise ValueError(
                    f"profile must be one of {list(_PROFILES)} "
                    f"or an int; got {profile!r}"
                )
            profile_int = _PROFILES[profile]
        elif isinstance(profile, int):
            profile_int = profile
        else:
            raise TypeError(
                f"profile must be str or int, got {type(profile).__name__}"
            )

        ctx_ptr = ctypes.c_void_p()
        rc = _capi._lib.voss_primes_ctx_new(
            ctypes.c_uint64(N),
            ctypes.c_int(profile_int),
            ctypes.byref(ctx_ptr),
        )
        _capi._check(rc, _ERRMAP)

        self._N = N
        self._profile = profile_int
        self._ctx = ctx_ptr
        self._prime_count_cache = None
        self._gap_cache = {}
        self._stats_cache = None
        self._cheb_cache = None
        self._large_gaps_cache = None
        self._sophie_cache = None

    # --- Context manager ---
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        return False  # don't suppress exceptions

    # --- Lifecycle ---
    def close(self):
        """Free the underlying GPU resources. Idempotent."""
        if self._ctx is not None:
            _capi._lib.voss_primes_ctx_free(self._ctx)
            self._ctx = None

    def __del__(self):
        # Best-effort cleanup (in case user forgot `with`)
        try:
            self.close()
        except Exception:
            pass

    # --- Properties ---
    @property
    def N(self) -> int:
        return self._N

    @property
    def profile(self) -> str:
        reverse = {v: k for k, v in _PROFILES.items()}
        return reverse.get(self._profile, str(self._profile))

    # --- Queries ---
    def prime_count(self) -> int:
        """Return pi(N). Cached after first call."""
        if self._ctx is None:
            raise VossError("Context is closed")

        if self._prime_count_cache is not None:
            return self._prime_count_cache

        out = ctypes.c_uint64(0)
        rc = _capi._lib.voss_primes_ctx_prime_count(
            self._ctx,
            ctypes.byref(out),
        )
        _capi._check(rc, _ERRMAP)
        self._prime_count_cache = out.value
        return out.value

    # --- M2: gap queries ---
    def _get_gap_count(self, lib_func, cache_key: str) -> int:
        """Internal: call a gap-count C function and cache result."""
        if self._ctx is None:
            raise VossError("Context is closed")

        cached = self._gap_cache.get(cache_key)
        if cached is not None:
            return cached

        out = ctypes.c_uint64(0)
        rc = lib_func(self._ctx, ctypes.byref(out))
        _capi._check(rc, _ERRMAP)
        self._gap_cache[cache_key] = out.value
        return out.value

    def twins(self) -> int:
        """Count twin prime pairs (gap == 2) up to N.

        Requires profile "standard" or "full".
        Result cached after first call.

        Examples
        --------
        >>> import voss
        >>> with voss.primes.Context(10**9) as ctx:
        ...     ctx.twins()
        3424506
        """
        return self._get_gap_count(
            _capi._lib.voss_primes_ctx_twins, "twins")

    def cousin(self) -> int:
        """Count cousin prime pairs (gap == 4) up to N.

        Requires profile "standard" or "full".
        Result cached after first call.
        """
        return self._get_gap_count(
            _capi._lib.voss_primes_ctx_cousin, "cousin")

    def sexy(self) -> int:
        """Count sexy prime pairs (gap == 6) up to N.

        Requires profile "standard" or "full".
        Result cached after first call.
        """
        return self._get_gap_count(
            _capi._lib.voss_primes_ctx_sexy, "sexy")

    def export_csv(self, prefix: str) -> list:
        """Export results to CSV files with the given prefix.

        Creates:
          <prefix>_chebyshev.csv   (pi_4_1, pi_4_3, difference)
          <prefix>_large_gaps.csv  (position, gap)
          <prefix>_stats.csv       (mean_gap, std_dev, skewness, kurtosis, total_gaps)

        Requires profile "standard" or "full".

        Returns
        -------
        list of str
            Paths to the files created.

        Examples
        --------
        >>> import voss
        >>> with voss.primes.Context(10**9) as ctx:
        ...     files = ctx.export_csv("/tmp/voss")
        ...     for f in files:
        ...         print(f)
        /tmp/voss_chebyshev.csv
        /tmp/voss_large_gaps.csv
        /tmp/voss_stats.csv
        """
        if self._ctx is None:
            raise VossError("Context is closed")
        if not isinstance(prefix, str):
            raise TypeError("prefix must be str")

        rc = _capi._lib.voss_primes_ctx_export_csv(
            self._ctx, prefix.encode('utf-8'))
        _capi._check(rc, _ERRMAP)

        return [
            prefix + "_chebyshev.csv",
            prefix + "_large_gaps.csv",
            prefix + "_stats.csv",
        ]

    def large_gaps(self) -> list:
        """Return list of large gaps (>= 500), sorted by gap size descending.

        Requires profile "standard" or "full". Cached after first call.

        Examples
        --------
        >>> import voss
        >>> with voss.primes.Context(10**12) as ctx:
        ...     gaps = ctx.large_gaps()
        ...     print(len(gaps), gaps[0])
        11 LargeGap(position=738,832,928,467, gap=540)
        """
        if self._ctx is None:
            raise VossError("Context is closed")

        if self._large_gaps_cache is not None:
            return self._large_gaps_cache

        count = ctypes.c_uint64(0)
        rc = _capi._lib.voss_primes_ctx_large_gaps_count(
            self._ctx, ctypes.byref(count))
        _capi._check(rc, _ERRMAP)

        result = []
        for i in range(count.value):
            pos = ctypes.c_uint64(0)
            gap = ctypes.c_uint32(0)
            rc = _capi._lib.voss_primes_ctx_large_gaps_get(
                self._ctx, ctypes.c_uint64(i),
                ctypes.byref(pos), ctypes.byref(gap))
            _capi._check(rc, _ERRMAP)
            result.append(LargeGap(position=pos.value, gap=gap.value))

        self._large_gaps_cache = result
        return result

    def sophie_germain(self) -> int:
        """Count Sophie Germain primes p <= N (where p and 2p+1 are both prime).

        Requires profile "standard" or "full". Currently supports N <= 5e7.

        Examples
        --------
        >>> import voss
        >>> with voss.primes.Context(1000) as ctx:
        ...     ctx.sophie_germain()
        37
        """
        if self._ctx is None:
            raise VossError("Context is closed")

        if self._sophie_cache is not None:
            return self._sophie_cache

        out = ctypes.c_uint64(0)
        rc = _capi._lib.voss_primes_ctx_sophie_germain(
            self._ctx, ctypes.byref(out))
        _capi._check(rc, _ERRMAP)
        self._sophie_cache = out.value
        return out.value

    def chebyshev(self) -> ChebyshevBias:
        """Return Chebyshev bias: counts of primes == 1 and 3 (mod 4).

        Requires profile "standard" or "full". Cached after first call.

        Examples
        --------
        >>> import voss
        >>> with voss.primes.Context(10**6) as ctx:
        ...     cb = ctx.chebyshev()
        ...     print(cb.pi_4_1, cb.pi_4_3, cb.difference)
        39175 39322 147
        """
        if self._ctx is None:
            raise VossError("Context is closed")

        if self._cheb_cache is not None:
            return self._cheb_cache

        c1 = ctypes.c_uint64(0)
        c3 = ctypes.c_uint64(0)
        rc = _capi._lib.voss_primes_ctx_chebyshev_bias(
            self._ctx, ctypes.byref(c1), ctypes.byref(c3))
        _capi._check(rc, _ERRMAP)

        cb = ChebyshevBias(pi_4_1=c1.value, pi_4_3=c3.value)
        self._cheb_cache = cb
        return cb

    def statistics(self) -> Statistics:
        """Return gap distribution statistics.

        Requires profile "standard" or "full".
        Result cached after first call.

        Examples
        --------
        >>> import voss
        >>> with voss.primes.Context(10**6) as ctx:
        ...     s = ctx.statistics()
        ...     print(f"mean gap: {s.mean_gap:.4f}")
        mean gap: 12.7391
        """
        if self._ctx is None:
            raise VossError("Context is closed")

        if self._stats_cache is not None:
            return self._stats_cache

        c_stats = _capi.VossPrimesStats()
        rc = _capi._lib.voss_primes_ctx_statistics(
            self._ctx, ctypes.byref(c_stats))
        _capi._check(rc, _ERRMAP)

        stats = Statistics(
            mean_gap=c_stats.mean_gap,
            std_dev=c_stats.std_dev,
            skewness=c_stats.skewness,
            kurtosis=c_stats.kurtosis,
            total_gaps=c_stats.total_gaps,
        )
        self._stats_cache = stats
        return stats


# ============================================================
# M3: direct module-level functions
# ============================================================

def in_range(a: int, b: int) -> list:
    """Return list of primes in [a, b] (inclusive).

    Uses GPU sieve. Default limit: 10^7 primes (80 MB).
    For larger ranges use `in_range_with_limit`.

    Parameters
    ----------
    a : int
        Lower bound (inclusive). Values < 2 are ignored.
    b : int
        Upper bound (inclusive). Must be <= 10^14.

    Returns
    -------
    list of int
        Primes in [a, b], sorted ascending.

    Examples
    --------
    >>> import voss
    >>> voss.primes.in_range(10, 30)
    [11, 13, 17, 19, 23, 29]
    >>> len(voss.primes.in_range(10**9, 10**9 + 100))
    6
    """
    if not isinstance(a, int) or not isinstance(b, int):
        raise TypeError("a and b must be int")
    if b < a:
        return []

    arr = ctypes.POINTER(ctypes.c_uint64)()
    count = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_in_range(
        ctypes.c_uint64(a), ctypes.c_uint64(b),
        ctypes.byref(arr), ctypes.byref(count),
    )
    _capi._check(rc, _ERRMAP)

    n = count.value
    if n == 0:
        return []
    try:
        return [int(arr[i]) for i in range(n)]
    finally:
        _capi._lib.voss_free(arr)


def in_range_with_limit(a: int, b: int, max_count: int) -> list:
    """Like in_range, but with a custom maximum count.

    Raises VossError if [a, b] contains more than max_count primes.
    """
    if not isinstance(a, int) or not isinstance(b, int):
        raise TypeError("a and b must be int")
    if not isinstance(max_count, int) or max_count <= 0:
        raise ValueError("max_count must be positive int")
    if b < a:
        return []

    arr = ctypes.POINTER(ctypes.c_uint64)()
    count = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_in_range_with_limit(
        ctypes.c_uint64(a), ctypes.c_uint64(b),
        ctypes.c_uint64(max_count),
        ctypes.byref(arr), ctypes.byref(count),
    )
    _capi._check(rc, _ERRMAP)

    n = count.value
    if n == 0:
        return []
    try:
        return [int(arr[i]) for i in range(n)]
    finally:
        _capi._lib.voss_free(arr)


def nth(n: int) -> int:
    """Return the n-th prime (1-indexed): nth(1)=2, nth(2)=3, ...

    Examples
    --------
    >>> import voss
    >>> voss.primes.nth(1)
    2
    >>> voss.primes.nth(1000)
    7919
    """
    if not isinstance(n, int):
        raise TypeError("n must be int")
    if n < 1:
        raise VossInvalidNError(f"n must be >= 1 (1-indexed), got {n}")

    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_nth(
        ctypes.c_uint64(n), ctypes.byref(out),
    )
    _capi._check(rc, _ERRMAP)
    return out.value


def next_prime(x: int) -> int:
    """Return the smallest prime strictly greater than x.

    Examples
    --------
    >>> import voss
    >>> voss.primes.next_prime(10)
    11
    >>> voss.primes.next_prime(10**9)
    1000000007
    """
    if not isinstance(x, int):
        raise TypeError("x must be int")

    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_next(
        ctypes.c_uint64(x), ctypes.byref(out),
    )
    _capi._check(rc, _ERRMAP)
    return out.value


def prev_prime(x: int) -> int:
    """Return the largest prime strictly less than x.

    Examples
    --------
    >>> import voss
    >>> voss.primes.prev_prime(10)
    7
    >>> voss.primes.prev_prime(100)
    97
    """
    if not isinstance(x, int):
        raise TypeError("x must be int")

    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_prev(
        ctypes.c_uint64(x), ctypes.byref(out),
    )
    _capi._check(rc, _ERRMAP)
    return out.value


def is_prime(x: int) -> bool:
    """Test if x is prime (deterministic Miller-Rabin).

    Examples
    --------
    >>> import voss
    >>> voss.primes.is_prime(7)
    True
    >>> voss.primes.is_prime(100)
    False
    """
    if not isinstance(x, int):
        raise TypeError(f"x must be int, got {type(x).__name__}")
    if x < 0:
        return False

    out = ctypes.c_int(0)
    rc = _capi._lib.voss_primes_is_prime(
        ctypes.c_uint64(x), ctypes.byref(out))
    _capi._check(rc, _ERRMAP)
    return out.value == 1


def factorize(x: int) -> list:
    """Factorize x into its prime factors (with multiplicity), sorted ascending.

    Uses Pollard rho + Miller-Rabin (deterministic).

    Examples
    --------
    >>> import voss
    >>> voss.primes.factorize(12)
    [2, 2, 3]
    >>> voss.primes.factorize(1000000007)  # prime
    [1000000007]
    >>> voss.primes.factorize(600851475143)
    [71, 839, 1471, 6857]
    """
    if not isinstance(x, int):
        raise TypeError(f"x must be int, got {type(x).__name__}")
    if x < 2:
        raise VossInvalidNError(f"x must be >= 2, got {x}")

    arr = ctypes.POINTER(ctypes.c_uint64)()
    count = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_factorize(
        ctypes.c_uint64(x), ctypes.byref(arr), ctypes.byref(count))
    _capi._check(rc, _ERRMAP)

    n = count.value
    if n == 0:
        return []
    try:
        return [int(arr[i]) for i in range(n)]
    finally:
        _capi._lib.voss_free(arr)


def is_mersenne_prime(p: int) -> bool:
    """Test if M_p = 2^p - 1 is prime (via Lucas-Lehmer).

    p must be in [2, 63].

    Examples
    --------
    >>> import voss
    >>> voss.primes.is_mersenne_prime(31)
    True
    >>> voss.primes.is_mersenne_prime(11)
    False
    """
    if not isinstance(p, int):
        raise TypeError(f"p must be int, got {type(p).__name__}")
    if p < 2:
        raise VossInvalidNError(f"p must be >= 2, got {p}")
    if p > 63:
        raise VossError(f"p must be <= 63, got {p}")

    out = ctypes.c_int(0)
    rc = _capi._lib.voss_primes_is_mersenne_prime(
        ctypes.c_uint32(p), ctypes.byref(out))
    _capi._check(rc, _ERRMAP)
    return out.value == 1


def is_fermat_prime(n: int) -> bool:
    """Test if F_n = 2^(2^n) + 1 is prime.

    n must be in [0, 5].

    Examples
    --------
    >>> import voss
    >>> voss.primes.is_fermat_prime(3)   # 257
    True
    >>> voss.primes.is_fermat_prime(5)   # 4294967297 = 641*6700417
    False
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    if n < 0:
        raise VossInvalidNError(f"n must be >= 0, got {n}")
    if n > 5:
        raise VossError(f"n must be <= 5, got {n}")

    out = ctypes.c_int(0)
    rc = _capi._lib.voss_primes_is_fermat_prime(
        ctypes.c_uint32(n), ctypes.byref(out))
    _capi._check(rc, _ERRMAP)
    return out.value == 1
