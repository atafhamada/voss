"""VOSS: GPU-accelerated prime gap library.

M0 scope: prime_count only.
"""

from . import primes
from .exceptions import VossError

__version__ = "0.1.0"

__all__ = ["primes", "VossError"]
