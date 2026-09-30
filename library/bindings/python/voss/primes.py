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
