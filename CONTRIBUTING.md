# Contributing to VOSS

Thanks for your interest in VOSS.

## Reporting bugs

Open an issue at:
https://github.com/atafhamada/voss/issues

Please include:
- VOSS version (`python -c "import voss; print(voss.__version__)"`)
- Python version and OS
- Minimal reproducible example

## Suggesting features

Open an issue with the label `enhancement`.
Describe the use case, not just the feature.

## Development setup

    git clone https://github.com/atafhamada/voss.git
    cd voss/library
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j

Requirements: NVIDIA GPU (Tier 1), CUDA 12.x, Python 3.9+, CMake 3.22+.

## Pull requests

- One concern per PR.
- Reference the related issue.
- Run the test suite before submitting:
      pytest library/tests/test_primes.py -v
- Add a test for any new behavior.

## Code style

- C++/CUDA: follow the existing style in `library/src/`.
- Python: PEP 8.
- Docs: English.

## License

By contributing, you agree that your contributions are licensed under BSL-1.1
(see `LICENSE`).
