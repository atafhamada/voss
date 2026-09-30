"""VOSS primes — user-facing API (M0: prime_count only)."""

import ctypes

from . import _capi
from ._capi import VOSS_OK, VOSS_ERR_INVALID_N, VOSS_ERR_INVALID_ARG
from .exceptions import VossError


class VossInvalidNError(VossError):
    """Raised when N < 2."""


class VossInvalidArgError(VossError):
    """Raised when an argument is invalid (e.g., NULL pointer)."""


_ERRMAP = {
    VOSS_ERR_INVALID_N: VossInvalidNError,
    VOSS_ERR_INVALID_ARG: VossInvalidArgError,
}


def prime_count(N: int) -> int:
    """Count primes less than or equal to N.

    Parameters
    ----------
    N : int
        Upper bound (must be >= 2).

    Returns
    -------
    int
        pi(N) — number of primes <= N.

    Raises
    ------
    VossInvalidNError
        If N < 2.
    VossError
        On any other error (CUDA failure, out of memory, etc.)

    Examples
    --------
    >>> import voss
    >>> voss.primes.prime_count(10**6)
    78498
    >>> voss.primes.prime_count(10**9)
    50847534
    """
    if not isinstance(N, int):
        raise TypeError(f"N must be int, got {type(N).__name__}")

    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_primes_prime_count(
        ctypes.c_uint64(N),
        ctypes.byref(out),
    )
    _capi._check(rc, _ERRMAP)
    return out.value
