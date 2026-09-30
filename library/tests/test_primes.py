"""M0 Python tests for voss.primes.prime_count.

These tests require a GPU with CUDA. Skip if not available.
"""

import os
import sys
from pathlib import Path

import pytest

# --- Setup: add bindings to path ---
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


def test_import_voss():
    import voss
    assert hasattr(voss, "primes")
    assert hasattr(voss.primes, "prime_count")
    assert voss.__version__ == "0.1.0"


@skip_no_cuda
@pytest.mark.parametrize("N,expected", [
    (2,          1),
    (3,          2),
    (5,          3),
    (10,         4),
    (100,        25),
    (10**6,      78_498),
    (10**7,      664_579),
    (10**8,      5_761_455),
    (10**9,      50_847_534),
])
def test_prime_count(N, expected):
    import voss
    assert voss.primes.prime_count(N) == expected


@skip_no_cuda
def test_invalid_n_raises():
    import voss
    with pytest.raises(voss.VossError):
        voss.primes.prime_count(0)
    with pytest.raises(voss.VossError):
        voss.primes.prime_count(1)
    with pytest.raises(voss.VossError):
        voss.primes.prime_count(-5)


def test_wrong_type_raises():
    import voss
    with pytest.raises(TypeError):
        voss.primes.prime_count("hello")
    with pytest.raises(TypeError):
        voss.primes.prime_count(3.14)


@skip_no_cuda
def test_consistency():
    import voss
    p8 = voss.primes.prime_count(10**8)
    p9 = voss.primes.prime_count(10**9)
    assert p8 < p9
