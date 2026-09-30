"""VOSS: GPU-accelerated prime gap library.

M1 scope: prime_count + Context (handle).
"""

from . import primes
from .primes import Context
from .exceptions import VossError

__version__ = "0.1.0"

__all__ = ["primes", "Context", "VossError"]
