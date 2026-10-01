"""VOSS numbers section (M6.2a) — arithmetic functions (CPU).

Current scope:
    phi(n) — Euler's totient.

Conventions:
    phi(1) == 1. Domain: n >= 1.
"""

import ctypes

from . import _capi
from .exceptions import VossError

__all__ = ["phi"]


def phi(n: int) -> int:
    """Euler's totient of n: count of 1 <= k <= n with gcd(k, n) == 1.

    Parameters
    ----------
    n : int
        Must be >= 1.

    Returns
    -------
    int
        phi(n). Convention: phi(1) = 1.

    Raises
    ------
    VossError
        On invalid input or internal failure.

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.phi(1)
    1
    >>> numbers.phi(12)
    4
    >>> numbers.phi(1000000007)  # prime
    1000000006
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_phi(
        ctypes.c_uint64(n), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_phi failed rc={rc}")
    return int(out.value)
