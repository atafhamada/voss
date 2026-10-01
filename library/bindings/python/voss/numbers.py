"""VOSS numbers section (M6.2a) — arithmetic functions (CPU).

Current scope:
    phi(n) — Euler's totient.

Conventions:
    phi(1) == 1. Domain: n >= 1.
"""

import ctypes

from . import _capi
from .exceptions import VossError

__all__ = ["phi", "tau", "sigma", "mu",
           "gcd", "lcm", "fibonacci", "factorial"]


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

def tau(n: int) -> int:
    """Divisor count: number of positive divisors of n.

    Parameters
    ----------
    n : int
        Must be >= 1.

    Returns
    -------
    int
        tau(n). Convention: tau(1) = 1.

    Raises
    ------
    VossError
        On invalid input or internal failure.

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.tau(1)
    1
    >>> numbers.tau(12)
    6
    >>> numbers.tau(97)  # prime
    2
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_tau(
        ctypes.c_uint64(n), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_tau failed rc={rc}")
    return int(out.value)

def sigma(n: int) -> int:
    """Sum of positive divisors of n.

    Parameters
    ----------
    n : int
        Must be >= 1.

    Returns
    -------
    int
        sigma(n). Convention: sigma(1) = 1.

    Raises
    ------
    VossError
        On invalid input or internal failure.

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.sigma(1)
    1
    >>> numbers.sigma(12)
    28
    >>> numbers.sigma(97)  # prime
    98
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_sigma(
        ctypes.c_uint64(n), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_sigma failed rc={rc}")
    return int(out.value)

def mu(n: int) -> int:
    """Moebius function.

    Returns
    -------
    int
        1  if n is squarefree with an even number of distinct primes,
        -1 if n is squarefree with an odd number of distinct primes,
        0  if n is not squarefree.
        Convention: mu(1) = 1.

    Parameters
    ----------
    n : int
        Must be >= 1.

    Raises
    ------
    VossError
        On invalid input or internal failure.

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.mu(1)
    1
    >>> numbers.mu(6)     # 2 * 3, squarefree, even count
    1
    >>> numbers.mu(30)    # 2 * 3 * 5, squarefree, odd count
    -1
    >>> numbers.mu(12)    # 2^2 * 3, not squarefree
    0
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    out = ctypes.c_int(0)
    rc = _capi._lib.voss_numbers_mu(
        ctypes.c_uint64(n), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_mu failed rc={rc}")
    return int(out.value)

def gcd(a: int, b: int) -> int:
    """Greatest common divisor.

    Convention: gcd(0, 0) = 0, gcd(a, 0) = a, gcd(0, b) = b.

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.gcd(12, 18)
    6
    >>> numbers.gcd(0, 0)
    0
    """
    if not isinstance(a, int) or not isinstance(b, int):
        raise TypeError("a and b must be int")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_gcd(
        ctypes.c_uint64(a), ctypes.c_uint64(b), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_gcd failed rc={rc}")
    return int(out.value)


def lcm(a: int, b: int) -> int:
    """Least common multiple.

    Convention: lcm(0, k) = lcm(k, 0) = 0.
    Raises VossError on uint64 overflow.

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.lcm(4, 6)
    12
    >>> numbers.lcm(0, 5)
    0
    """
    if not isinstance(a, int) or not isinstance(b, int):
        raise TypeError("a and b must be int")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_lcm(
        ctypes.c_uint64(a), ctypes.c_uint64(b), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_lcm failed rc={rc}")
    return int(out.value)


def fibonacci(n: int) -> int:
    """Fibonacci number F(n), fast doubling O(log n).

    Domain: n <= 93 (F(94) overflows uint64).

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.fibonacci(0)
    0
    >>> numbers.fibonacci(10)
    55
    >>> numbers.fibonacci(93)
    12200160415121876738
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_fibonacci(
        ctypes.c_uint64(n), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_fibonacci failed rc={rc}")
    return int(out.value)


def factorial(n: int) -> int:
    """Factorial n!. 0! = 1. Iterative.

    Domain: n <= 20 (21! overflows uint64).

    Examples
    --------
    >>> from voss import numbers
    >>> numbers.factorial(0)
    1
    >>> numbers.factorial(5)
    120
    >>> numbers.factorial(20)
    2432902008176640000
    """
    if not isinstance(n, int):
        raise TypeError(f"n must be int, got {type(n).__name__}")
    out = ctypes.c_uint64(0)
    rc = _capi._lib.voss_numbers_factorial(
        ctypes.c_uint64(n), ctypes.byref(out))
    if rc != 0:
        msg = _capi._lib.voss_get_last_error()
        raise VossError(msg.decode() if msg else f"voss_numbers_factorial failed rc={rc}")
    return int(out.value)
