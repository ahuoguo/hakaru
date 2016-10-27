# Testing infrastructure in Hakaru

Hakaru can be tested by running `cabal test` from the
root directory of the project.

Tests written in Hakaru will be found in the `tests/`
subdirectory at the root of the project. Tests written
in Haskell can be found at `haskell/Tests/`.

Note: tests related to `simplify` and which require Maple will also be
run if a local installation of Maple is detected.
