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


# ============================================================
# M1 tests — Context (handle)
# ============================================================

@skip_no_cuda
def test_context_basic():
    import voss
    with voss.primes.Context(10**9) as ctx:
        assert ctx.prime_count() == 50_847_534


@skip_no_cuda
def test_context_caching():
    import voss
    with voss.primes.Context(10**8) as ctx:
        p1 = ctx.prime_count()
        p2 = ctx.prime_count()
        assert p1 == p2 == 5_761_455


@skip_no_cuda
def test_context_properties():
    import voss
    with voss.primes.Context(10**6, profile="full") as ctx:
        assert ctx.N == 10**6
        assert ctx.profile == "full"


@skip_no_cuda
@pytest.mark.parametrize("profile", ["minimal", "standard", "full"])
def test_context_profiles(profile):
    import voss
    with voss.primes.Context(10**6, profile=profile) as ctx:
        assert ctx.prime_count() == 78_498


def test_context_invalid_n():
    import voss
    with pytest.raises(voss.VossError):
        voss.primes.Context(0)
    with pytest.raises(voss.VossError):
        voss.primes.Context(1)
    with pytest.raises(voss.VossError):
        voss.primes.Context(-10)


def test_context_invalid_profile():
    import voss
    with pytest.raises(ValueError):
        voss.primes.Context(10**6, profile="invalid")


def test_context_closed_raises():
    import voss
    ctx = voss.primes.Context(10**6)
    ctx.close()
    with pytest.raises(voss.VossError):
        ctx.prime_count()


@skip_no_cuda
def test_context_multiple_instances():
    import voss
    with voss.primes.Context(10**6) as c1, \
         voss.primes.Context(10**7) as c2:
        assert c1.prime_count() == 78_498
        assert c2.prime_count() == 664_579


# ============================================================
# M2 tests — twins, cousin, sexy
# ============================================================

@skip_no_cuda
def test_twins_10e9():
    import voss
    with voss.primes.Context(10**9) as ctx:
        assert ctx.twins() == 3_424_506


@skip_no_cuda
def test_cousin_10e9():
    import voss
    with voss.primes.Context(10**9) as ctx:
        assert ctx.cousin() == 3_424_679


@skip_no_cuda
def test_sexy_10e9():
    import voss
    with voss.primes.Context(10**9) as ctx:
        assert ctx.sexy() == 6_089_791


@skip_no_cuda
def test_gaps_all_at_once():
    import voss
    with voss.primes.Context(10**9) as ctx:
        assert ctx.twins()  == 3_424_506
        assert ctx.cousin() == 3_424_679
        assert ctx.sexy()   == 6_089_791


@skip_no_cuda
def test_gaps_caching():
    import voss
    with voss.primes.Context(10**8) as ctx:
        t1 = ctx.twins()
        t2 = ctx.twins()  # cached
        assert t1 == t2 == 440_312


def test_gaps_rejected_on_minimal():
    import voss
    with voss.primes.Context(10**6, profile="minimal") as ctx:
        with pytest.raises(voss.VossError):
            ctx.twins()


@skip_no_cuda
def test_gaps_on_full_profile():
    import voss
    with voss.primes.Context(10**6, profile="full") as ctx:
        # Same values as standard, since histogram is the same
        assert ctx.twins() == 8_169
