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
