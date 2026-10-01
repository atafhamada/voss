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
