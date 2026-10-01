"""Tests for voss.conjectures — empirical conjecture tests (DESIGN.md 6.14).

These tests verify the wrapper layer (validation, return shape,
counterexample detection). The underlying math is tested in
test_primes.py.
"""

import os
import sys
from pathlib import Path

import pytest

# --- Setup: add bindings to path (mirrors test_primes.py) ---
REPO_ROOT = Path(__file__).resolve().parents[2]
BINDINGS = REPO_ROOT / "library" / "bindings" / "python"
BUILD_SO = REPO_ROOT / "library" / "build" / "libvoss.so"

if str(BINDINGS) not in sys.path:
    sys.path.insert(0, str(BINDINGS))

if BUILD_SO.exists():
    os.environ["VOSS_LIBRARY_PATH"] = str(BUILD_SO)


def _cuda_available():
    try:
        import voss
        voss.primes.prime_count(10)
        return True
    except Exception:
        return False


HAS_CUDA = _cuda_available()
skip_no_cuda = pytest.mark.skipif(not HAS_CUDA, reason="Requires CUDA GPU")


# ============================================================
# API surface
# ============================================================

def test_conjectures_module_exists():
    import voss
    assert hasattr(voss, "conjectures")


def test_all_exports():
    import voss.conjectures as c
    assert set(c.__all__) == {
        "test_bertrand_upto",
        "test_legendre_upto",
        "test_goldbach_upto",
        "test_chebyshev_bias_upto",
    }


# ============================================================
# Return shape
# ============================================================

@skip_no_cuda
def test_return_shape():
    import voss
    r = voss.conjectures.test_bertrand_upto(10)
    assert set(r.keys()) == {"conjecture", "N", "status",
                             "counterexamples", "note"}
    assert r["conjecture"] == "bertrand"
    assert r["N"] == 10
    assert "Empirical test" in r["note"]
    assert "Does NOT prove" in r["note"]


@skip_no_cuda
def test_counterexamples_is_list():
    import voss
    r = voss.conjectures.test_bertrand_upto(10)
    assert isinstance(r["counterexamples"], list)


# ============================================================
# Bertrand (proven — never finds counterexample)
# ============================================================

@skip_no_cuda
def test_bertrand_no_counterexample():
    import voss
    r = voss.conjectures.test_bertrand_upto(1000)
    assert r["status"] == "no_counterexample_found_upto_N"
    assert r["counterexamples"] == []


@skip_no_cuda
def test_bertrand_min_N():
    import voss
    r = voss.conjectures.test_bertrand_upto(2)
    assert r["status"] == "no_counterexample_found_upto_N"


# ============================================================
# Legendre (open — no counterexample known)
# ============================================================

@skip_no_cuda
def test_legendre_no_counterexample():
    import voss
    r = voss.conjectures.test_legendre_upto(10**4)
    assert r["status"] == "no_counterexample_found_upto_N"
    assert r["counterexamples"] == []


# ============================================================
# Goldbach (open — no counterexample known)
# ============================================================

@skip_no_cuda
def test_goldbach_no_counterexample():
    import voss
    r = voss.conjectures.test_goldbach_upto(1000)
    assert r["status"] == "no_counterexample_found_upto_N"


# ============================================================
# Chebyshev bias (has KNOWN counterexamples at small x)
# ============================================================

@skip_no_cuda
def test_chebyshev_bias_known_counterexamples():
    """First three counterexamples are 5, 17, 41 (known mathematically)."""
    import voss
    r = voss.conjectures.test_chebyshev_bias_upto(100)
    assert r["status"] == "counterexample_found"
    assert 5 in r["counterexamples"]
    assert 17 in r["counterexamples"]
    assert 41 in r["counterexamples"]


@skip_no_cuda
def test_chebyshev_bias_counterexamples_truncated():
    """At most 10 counterexamples are returned."""
    import voss
    r = voss.conjectures.test_chebyshev_bias_upto(1000)
    assert len(r["counterexamples"]) <= 10


# ============================================================
# Input validation — TypeError
# ============================================================

def test_bertrand_type_error():
    import voss
    with pytest.raises(TypeError):
        voss.conjectures.test_bertrand_upto("hello")


def test_legendre_type_error():
    import voss
    with pytest.raises(TypeError):
        voss.conjectures.test_legendre_upto(3.14)


def test_goldbach_type_error():
    import voss
    with pytest.raises(TypeError):
        voss.conjectures.test_goldbach_upto(None)


def test_chebyshev_bias_type_error():
    import voss
    with pytest.raises(TypeError):
        voss.conjectures.test_chebyshev_bias_upto([100])


# ============================================================
# Input validation — N out of range
# ============================================================

def test_bertrand_min_N_error():
    import voss
    with pytest.raises(voss.VossError):
        voss.conjectures.test_bertrand_upto(1)


def test_bertrand_max_N_error():
    import voss
    with pytest.raises(voss.VossError):
        voss.conjectures.test_bertrand_upto(10**8)


def test_legendre_min_N_error():
    import voss
    with pytest.raises(voss.VossError):
        voss.conjectures.test_legendre_upto(1)


def test_goldbach_min_N_error():
    import voss
    with pytest.raises(voss.VossError):
        voss.conjectures.test_goldbach_upto(3)


def test_goldbach_max_N_error():
    import voss
    # max_N is now 10^8 (GPU path); 10^9 exceeds it
    with pytest.raises(voss.VossError):
        voss.conjectures.test_goldbach_upto(10**9)


def test_chebyshev_bias_min_N_error():
    import voss
    with pytest.raises(voss.VossError):
        voss.conjectures.test_chebyshev_bias_upto(2)


def test_chebyshev_bias_max_N_error():
    import voss
    with pytest.raises(voss.VossError):
        voss.conjectures.test_chebyshev_bias_upto(10**8)
