"""VOSS conjectures - empirical tests of well-known prime conjectures.

These functions TEST conjectures up to a user-supplied N.
They do NOT prove anything. A "no counterexample found" result is
empirical evidence, not a proof.

See DESIGN.md section 6.14 for scope and naming conventions.
Naming convention: test_<conjecture>_upto(N).
"""

import math

from . import primes


_NOTE = "Empirical test up to N. Does NOT prove the conjecture."


def _make_result(conjecture, N, counterexamples):
    """Build a uniform result dict."""
    if counterexamples:
        status = "counterexample_found"
    else:
        status = "no_counterexample_found_upto_N"
    return {
        "conjecture": conjecture,
        "N": N,
        "status": status,
        "counterexamples": list(counterexamples[:10]),
        "note": _NOTE,
    }


def _validate_N(N, min_N, max_N):
    if not isinstance(N, int):
        raise TypeError(f"N must be int, got {type(N).__name__}")
    if N < min_N:
        raise primes.VossInvalidNError(
            f"N must be >= {min_N} for this test, got {N}"
        )
    if N > max_N:
        raise primes.VossInvalidArgError(
            f"N must be <= {max_N} for this test, got {N}. "
            f"See DESIGN.md 6.14 for documented limits."
        )


def test_bertrand_upto(N):
    """Test Bertrand's postulate up to N.

    Statement: for every integer n >= 2, there is a prime p with
    n < p < 2n.

    Empirical test: for each n in [2, N], check next_prime(n) < 2*n.

    Parameters
    ----------
    N : int
        Upper bound (2 <= N <= 10^7).

    Returns
    -------
    dict with keys: conjecture, N, status, counterexamples, note.

    Notes
    -----
    Does NOT prove the conjecture (proven by Chebyshev 1852).

    Examples
    --------
    >>> import voss
    >>> r = voss.conjectures.test_bertrand_upto(1000)
    >>> r["status"]
    'no_counterexample_found_upto_N'
    """
    _validate_N(N, min_N=2, max_N=10**7)
    counterexamples = []
    for n in range(2, N + 1):
        p = primes.next_prime(n)
        if p >= 2 * n:
            counterexamples.append(n)
            if len(counterexamples) >= 10:
                break
    return _make_result("bertrand", N, counterexamples)


def test_legendre_upto(N):
    """Test Legendre's conjecture up to N.

    Statement: for every n >= 1, there is a prime p with
    n^2 < p < (n+1)^2.

    Empirical test: for each n in [1, isqrt(N)-1], check
    next_prime(n^2) < (n+1)^2.

    Parameters
    ----------
    N : int
        Upper bound (2 <= N <= 10^14).

    Returns
    -------
    dict

    Notes
    -----
    Does NOT prove the conjecture (still open as of 2026).
    Complexity O(sqrt(N)) calls to next_prime.

    Examples
    --------
    >>> import voss
    >>> r = voss.conjectures.test_legendre_upto(10**6)
    >>> r["status"]
    'no_counterexample_found_upto_N'
    """
    _validate_N(N, min_N=2, max_N=10**14)
    n_max = math.isqrt(N)
    counterexamples = []
    for n in range(1, n_max):
        upper = (n + 1) * (n + 1)
        if upper > N:
            break
        p = primes.next_prime(n * n)
        if p >= upper:
            counterexamples.append(n)
            if len(counterexamples) >= 10:
                break
    return _make_result("legendre", N, counterexamples)


def test_goldbach_upto(N):
    """Test Goldbach's conjecture up to N.

    Statement: every even integer n >= 4 is the sum of two primes.

    Empirical test: for each even n in [4, N], check
    goldbach_count(n) > 0.

    Parameters
    ----------
    N : int
        Upper bound (4 <= N <= 10^6).
        Limited by CPU-based goldbach_count (see STATE.md).

    Returns
    -------
    dict

    Notes
    -----
    Does NOT prove the conjecture (still open as of 2026).

    Examples
    --------
    >>> import voss
    >>> r = voss.conjectures.test_goldbach_upto(100)
    >>> r["status"]
    'no_counterexample_found_upto_N'
    """
    _validate_N(N, min_N=4, max_N=10**6)
    counterexamples = []
    for n in range(4, N + 1, 2):
        if primes.goldbach_count(n) == 0:
            counterexamples.append(n)
            if len(counterexamples) >= 10:
                break
    return _make_result("goldbach", N, counterexamples)


def test_chebyshev_bias_upto(N):
    """Test Chebyshev's bias (strict form) up to N.

    Statement tested: for every x <= N, pi(x; 4,3) > pi(x; 4,1),
    where pi(x; 4,a) counts primes <= x that are == a (mod 4).

    Empirical test: scan primes <= N in order, tracking cumulative
    counts, and report any point where pi(x; 4,3) <= pi(x; 4,1).

    Parameters
    ----------
    N : int
        Upper bound (3 <= N <= 10^7).
        Limited by in_range memory (~80 MB).

    Returns
    -------
    dict

    Notes
    -----
    Does NOT prove the conjecture. The strict form fails at small x
    (e.g., 5, 17, 41) and is known to fail infinitely often
    (Littlewood 1914). Practical N <= 10^9 finds only the small
    counterexamples. This function reports them honestly.

    Examples
    --------
    >>> import voss
    >>> r = voss.conjectures.test_chebyshev_bias_upto(100)
    >>> r["status"]
    'counterexample_found'
    >>> 5 in r["counterexamples"]
    True
    """
    _validate_N(N, min_N=3, max_N=10**7)
    counterexamples = []
    ps = primes.in_range(2, N)
    c1 = 0
    c3 = 0
    for p in ps:
        if p == 2:
            continue
        if p % 4 == 1:
            c1 += 1
        else:  # p % 4 == 3
            c3 += 1
        if c3 <= c1:
            counterexamples.append(p)
            if len(counterexamples) >= 10:
                break
    return _make_result("chebyshev_bias", N, counterexamples)


__all__ = [
    "test_bertrand_upto",
    "test_legendre_upto",
    "test_goldbach_upto",
    "test_chebyshev_bias_upto",
]
