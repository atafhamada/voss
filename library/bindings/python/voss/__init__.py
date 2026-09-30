"""VOSS: GPU-accelerated prime gap library.

M3 scope: prime_count + Context + range + nth + next/prev.
"""

from . import primes
from .primes import Context
from .exceptions import VossError

__version__ = "0.4.0"

__all__ = ["primes", "Context", "VossError"]
