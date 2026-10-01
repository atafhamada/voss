"""Tests for voss.numbers (M6.2a)."""

import pytest

from voss import numbers
from voss.exceptions import VossError


def test_phi_small():
    assert numbers.phi(1) == 1
    assert numbers.phi(2) == 1
    assert numbers.phi(3) == 2
    assert numbers.phi(4) == 2
    assert numbers.phi(12) == 4
    assert numbers.phi(100) == 40


def test_phi_prime():
    assert numbers.phi(2) == 1
    assert numbers.phi(7) == 6
    assert numbers.phi(97) == 96
    assert numbers.phi(1000000007) == 1000000006


def test_phi_powers_of_two():
    assert numbers.phi(2) == 1
    assert numbers.phi(4) == 2
    assert numbers.phi(8) == 4
    assert numbers.phi(1024) == 512


def test_phi_invalid():
    with pytest.raises(VossError):
        numbers.phi(0)
    with pytest.raises(TypeError):
        numbers.phi(3.5)
    with pytest.raises(TypeError):
        numbers.phi("12")


def test_phi_vs_sympy_1_to_1000():
    """Cross-check against sympy.totient for n in [1, 1000]."""
    sympy = pytest.importorskip("sympy")
    for n in range(1, 1001):
        assert numbers.phi(n) == sympy.totient(n), f"mismatch at n={n}"

# ============================================================
# tau (M6.2b)
# ============================================================


def test_tau_small():
    assert numbers.tau(1) == 1
    assert numbers.tau(2) == 2
    assert numbers.tau(4) == 3
    assert numbers.tau(6) == 4
    assert numbers.tau(12) == 6
    assert numbers.tau(100) == 9
    assert numbers.tau(360) == 24   # 360 = 2^3 * 3^2 * 5 -> 4*3*2


def test_tau_prime():
    assert numbers.tau(2) == 2
    assert numbers.tau(97) == 2
    assert numbers.tau(1000000007) == 2


def test_tau_powers():
    # tau(p^k) = k+1
    assert numbers.tau(2**10) == 11
    assert numbers.tau(3**5) == 6


def test_tau_invalid():
    with pytest.raises(VossError):
        numbers.tau(0)
    with pytest.raises(TypeError):
        numbers.tau(3.5)


def test_tau_vs_sympy_1_to_1000():
    sympy = pytest.importorskip("sympy")
    for n in range(1, 1001):
        assert numbers.tau(n) == sympy.divisor_count(n), f"mismatch at n={n}"

# ============================================================
# sigma (M6.2b)
# ============================================================


def test_sigma_small():
    assert numbers.sigma(1) == 1
    assert numbers.sigma(2) == 3
    assert numbers.sigma(6) == 12
    assert numbers.sigma(12) == 28
    assert numbers.sigma(28) == 56      # perfect number
    assert numbers.sigma(100) == 217
    assert numbers.sigma(360) == 1170   # 360 = 2^3 * 3^2 * 5


def test_sigma_prime():
    assert numbers.sigma(2) == 3
    assert numbers.sigma(97) == 98
    assert numbers.sigma(1000000007) == 1000000008


def test_sigma_prime_power():
    # sigma(p^k) = (p^(k+1) - 1) / (p - 1)
    assert numbers.sigma(2**10) == 2047     # 2^11 - 1
    assert numbers.sigma(3**5) == 364       # (3^6-1)/2


def test_sigma_invalid():
    with pytest.raises(VossError):
        numbers.sigma(0)
    with pytest.raises(TypeError):
        numbers.sigma(3.5)


def test_sigma_vs_sympy_1_to_1000():
    sympy = pytest.importorskip("sympy")
    for n in range(1, 1001):
        assert numbers.sigma(n) == sympy.divisor_sigma(n, 1), f"mismatch at n={n}"

# ============================================================
# mu (M6.2b)
# ============================================================


def test_mu_small():
    assert numbers.mu(1) == 1
    assert numbers.mu(2) == -1
    assert numbers.mu(3) == -1
    assert numbers.mu(6) == 1          # 2*3, even
    assert numbers.mu(30) == -1        # 2*3*5, odd
    assert numbers.mu(210) == 1        # 2*3*5*7, even
    assert numbers.mu(12) == 0         # 2^2 * 3
    assert numbers.mu(4) == 0
    assert numbers.mu(9) == 0
    assert numbers.mu(100) == 0        # 2^2 * 5^2


def test_mu_prime():
    assert numbers.mu(2) == -1
    assert numbers.mu(97) == -1
    assert numbers.mu(1000000007) == -1


def test_mu_invalid():
    with pytest.raises(VossError):
        numbers.mu(0)
    with pytest.raises(TypeError):
        numbers.mu(3.5)


def test_mu_vs_sympy_1_to_1000():
    sympy = pytest.importorskip("sympy")
    from sympy import mobius
    for n in range(1, 1001):
        assert numbers.mu(n) == mobius(n), f"mismatch at n={n}"

# ============================================================
# gcd, lcm, fibonacci, factorial (M6.2c)
# ============================================================


def test_gcd_small():
    assert numbers.gcd(12, 18) == 6
    assert numbers.gcd(48, 18) == 6
    assert numbers.gcd(17, 5) == 1
    assert numbers.gcd(100, 75) == 25


def test_gcd_zero():
    assert numbers.gcd(0, 0) == 0
    assert numbers.gcd(5, 0) == 5
    assert numbers.gcd(0, 7) == 7


def test_gcd_invalid():
    with pytest.raises(TypeError):
        numbers.gcd(3.5, 2)
    with pytest.raises(TypeError):
        numbers.gcd(2, "5")


def test_gcd_vs_sympy():
    sympy = pytest.importorskip("sympy")
    from sympy import igcd
    for a in range(0, 50):
        for b in range(0, 50):
            assert numbers.gcd(a, b) == igcd(a, b), f"at a={a} b={b}"


def test_lcm_small():
    assert numbers.lcm(4, 6) == 12
    assert numbers.lcm(21, 6) == 42
    assert numbers.lcm(7, 11) == 77


def test_lcm_zero():
    assert numbers.lcm(0, 5) == 0
    assert numbers.lcm(7, 0) == 0
    assert numbers.lcm(0, 0) == 0


def test_lcm_overflow():
    big = 2**63
    with pytest.raises(VossError):
        numbers.lcm(big, 3)


def test_lcm_invalid():
    with pytest.raises(TypeError):
        numbers.lcm(3.5, 2)


def test_lcm_vs_sympy():
    sympy = pytest.importorskip("sympy")
    from sympy import ilcm
    for a in range(0, 30):
        for b in range(0, 30):
            assert numbers.lcm(a, b) == ilcm(a, b), f"at a={a} b={b}"


def test_fibonacci_small():
    expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
    for n, val in enumerate(expected):
        assert numbers.fibonacci(n) == val


def test_fibonacci_edge():
    assert numbers.fibonacci(92) == 7540113804746346429
    assert numbers.fibonacci(93) == 12200160415121876738
    with pytest.raises(VossError):
        numbers.fibonacci(94)


def test_fibonacci_invalid():
    with pytest.raises(TypeError):
        numbers.fibonacci(3.5)


def test_fibonacci_vs_sympy():
    sympy = pytest.importorskip("sympy")
    for n in range(0, 94):
        assert numbers.fibonacci(n) == int(sympy.fibonacci(n)), f"at n={n}"


def test_factorial_small():
    assert numbers.factorial(0) == 1
    assert numbers.factorial(1) == 1
    assert numbers.factorial(5) == 120
    assert numbers.factorial(10) == 3628800


def test_factorial_edge():
    assert numbers.factorial(20) == 2432902008176640000
    with pytest.raises(VossError):
        numbers.factorial(21)


def test_factorial_invalid():
    with pytest.raises(TypeError):
        numbers.factorial(3.5)


def test_factorial_vs_sympy():
    sympy = pytest.importorskip("sympy")
    for n in range(0, 21):
        assert numbers.factorial(n) == int(sympy.factorial(n)), f"at n={n}"
