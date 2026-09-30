"""VOSS: GPU-accelerated prime gap library.

M4 scope: prime_count + Context + range + nth + next/prev + statistics.
"""

from . import primes
from .primes import Context, Statistics
from .exceptions import VossError

__version__ = "0.4.1"

__all__ = ["primes", "Context", "Statistics", "VossError"]
