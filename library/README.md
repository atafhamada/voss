# VOSS Library

**GPU-accelerated prime gap library** (part of [VOSS](../)).

## Status

**v0.1.0** — M0 complete. Only `prime_count` is implemented.

## Requirements

- NVIDIA GPU (Tier 1: A100 `sm_80`, T4 `sm_75`)
- CUDA Toolkit 12.x
- Python 3.9+ (for Python bindings)
- CMake 3.22+

## Build (C++)

```bash
cd library
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Artifacts:
- `build/libvoss_core.a` — static library
- `build/libvoss.so` — shared library (for Python)
- `build/test_prime_count` — C++ test binary

## Build (Python, in-place)

The Python bindings load `libvoss.so` at runtime. Set the path once:

```python
import os, sys
os.environ['VOSS_LIBRARY_PATH'] = '/path/to/library/build/libvoss.so'
sys.path.insert(0, '/path/to/library/bindings/python')

import voss
print(voss.primes.prime_count(10**9))  # 50847534
```

## Run tests

**C++** (requires GPU):

```bash
cd library/build
ctest --output-on-failure
```

**Python** (requires GPU):

```bash
pip install -r library/tests/requirements.txt
pytest library/tests/test_primes.py -v
```

## API (v0.1.0)

### C ABI

```c
#include <voss/voss.h>
#include <voss/voss_primes.h>

uint64_t out;
int rc = voss_primes_prime_count(1000000000ULL, &out);
if (rc != VOSS_OK) {
    fprintf(stderr, "%s\n", voss_get_last_error());
}
```

### Python

```python
import voss

n = voss.primes.prime_count(10**9)  # 50847534
```

## What's next

M1: handle + profiles. See [DESIGN.md](../DESIGN.md) and [M0_PLAN.md](../M0_PLAN.md).
