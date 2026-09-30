"""Internal: ctypes loader and C ABI declarations.

Do not import directly — use `voss.primes` instead.
"""

import ctypes
import os
import sys
from pathlib import Path

from .exceptions import VossError


def _find_library():
    """Locate libvoss.so. Search order:

    1. VOSS_LIBRARY_PATH environment variable (explicit override)
    2. Same directory as this package (installed wheel)
    3. Standard build directory (development layout)
    """
    # 1. Explicit override
    env_path = os.environ.get("VOSS_LIBRARY_PATH")
    if env_path:
        if not os.path.exists(env_path):
            raise VossError(f"VOSS_LIBRARY_PATH does not exist: {env_path}")
        return env_path

    # 2. Installed alongside this module
    pkg_dir = Path(__file__).parent
    for name in ["libvoss.so", "libvoss.dylib", "voss.dll"]:
        candidate = pkg_dir / name
        if candidate.exists():
            return str(candidate)

    # 3. Development build directory
    #    .../voss/library/bindings/python/voss/_capi.py
    #    -> .../voss/library/build/libvoss.so
    dev_candidate = pkg_dir.parent.parent.parent / "build" / "libvoss.so"
    if dev_candidate.exists():
        return str(dev_candidate)

    raise VossError(
        "libvoss.so not found. "
        "Set VOSS_LIBRARY_PATH or build the library first."
    )


# === M4: statistics struct ===
class VossPrimesStats(ctypes.Structure):
    _fields_ = [
        ("mean_gap",   ctypes.c_double),
        ("std_dev",    ctypes.c_double),
        ("skewness",   ctypes.c_double),
        ("kurtosis",   ctypes.c_double),
        ("total_gaps", ctypes.c_uint64),
    ]


_lib = ctypes.CDLL(_find_library())

# === Function signatures ===
_lib.voss_primes_prime_count.argtypes = [
    ctypes.c_uint64,
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_prime_count.restype = ctypes.c_int

_lib.voss_strerror.argtypes = [ctypes.c_int]
_lib.voss_strerror.restype = ctypes.c_char_p

_lib.voss_get_last_error.argtypes = []
_lib.voss_get_last_error.restype = ctypes.c_char_p

# === M3: direct functions ===
_lib.voss_primes_in_range.argtypes = [
    ctypes.c_uint64, ctypes.c_uint64,
    ctypes.POINTER(ctypes.POINTER(ctypes.c_uint64)),
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_in_range.restype = ctypes.c_int

_lib.voss_primes_in_range_with_limit.argtypes = [
    ctypes.c_uint64, ctypes.c_uint64, ctypes.c_uint64,
    ctypes.POINTER(ctypes.POINTER(ctypes.c_uint64)),
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_in_range_with_limit.restype = ctypes.c_int

_lib.voss_primes_nth.argtypes = [
    ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_nth.restype = ctypes.c_int

_lib.voss_primes_next.argtypes = [
    ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_next.restype = ctypes.c_int

_lib.voss_primes_prev.argtypes = [
    ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_prev.restype = ctypes.c_int

_lib.voss_free.argtypes = [ctypes.c_void_p]
_lib.voss_free.restype = None

# === Handle (M1) ===
_lib.voss_primes_ctx_new.argtypes = [
    ctypes.c_uint64,
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_void_p),
]
_lib.voss_primes_ctx_new.restype = ctypes.c_int

_lib.voss_primes_ctx_free.argtypes = [ctypes.c_void_p]
_lib.voss_primes_ctx_free.restype = None

_lib.voss_primes_ctx_prime_count.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_ctx_prime_count.restype = ctypes.c_int

_lib.voss_primes_ctx_twins.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_ctx_twins.restype = ctypes.c_int

_lib.voss_primes_ctx_cousin.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_ctx_cousin.restype = ctypes.c_int

_lib.voss_primes_ctx_sexy.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_uint64),
]
_lib.voss_primes_ctx_sexy.restype = ctypes.c_int

_lib.voss_primes_ctx_statistics.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(VossPrimesStats),
]
_lib.voss_primes_ctx_statistics.restype = ctypes.c_int


# === Error codes (mirror voss.h) ===
VOSS_OK = 0
VOSS_ERR_INVALID_N = 1
VOSS_ERR_OUT_OF_RANGE = 2
VOSS_ERR_NO_CUDA = 3
VOSS_ERR_OUT_OF_MEMORY = 4
VOSS_ERR_CUDA = 5
VOSS_ERR_INVALID_ARG = 6
VOSS_ERR_INTERNAL = 7

# === Profiles (M1) ===
VOSS_PROFILE_MINIMAL = 0
VOSS_PROFILE_STANDARD = 1
VOSS_PROFILE_FULL = 2


def _check(rc: int, errcode_map: dict):
    """Raise VossError if rc != VOSS_OK, using the mapped exception class."""
    if rc == VOSS_OK:
        return
    cls = errcode_map.get(rc, VossError)
    msg = _lib.voss_get_last_error().decode("utf-8", errors="replace")
    short = _lib.voss_strerror(rc).decode("utf-8", errors="replace")
    raise cls(f"{short}: {msg}")
