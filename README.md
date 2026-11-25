# PSP6

**PSP6** is a performance-focused Windows build and optimization layer for the open-source PPSSPP emulator.

It tracks the upstream emulator as a pinned Git submodule instead of copying thousands of files into a stale fork. That keeps upstream fixes available, makes every PSP6 change auditable, and allows performance patches to be tested against an exact source revision.

## Current source baseline

- Upstream: https://github.com/hrydgard/PPSSPP
- Pinned revision: `ee4594feff26e6a5c0bc2accfed19e9c5c117083`
- Revision date: 2026-11-24
- Upstream license: GPL-2.0-or-later (see `upstream/PPSSPP/LICENSE.TXT`)

## Windows x64 build

Requirements:

- Git (with submodule support)
- MinGW-w64 x86_64 UCRT GCC 15.2 or compatible
- CMake 3.16+
- Ninja

From a fresh clone:

```bat
git clone https://github.com/chesshook/PSP6.git
cd PSP6
build-psp6-mingw.bat
```

The build script initializes the pinned source and its dependencies, configures a Release build for the local x64 CPU, enables GCC link-time optimization and dead-section removal, and copies the resulting executable to `dist/PSP6.exe`.

The `-march=native` build is machine-specific: the resulting executable is tuned for the PC that compiles it and may not run on older CPUs. Do not distribute that binary as a universal x64 build.

## Optimization rules

PSP6 prioritizes real frame-time and latency improvements while preserving PSP instruction semantics:

- Keep JIT and interpreter behavior correct and deterministic.
- Preserve floating-point edge cases; do not use `-ffast-math` or `-Ofast` for the emulator core.
- Measure CPU, GPU, audio, and presentation costs independently.
- Keep performance patches isolated, benchmarkable, and reversible.
- Never trade save-state compatibility or game accuracy for synthetic benchmark numbers.

## Development status

This repository contains a pinned PPSSPP source baseline, a MinGW-native Release build, and the first PSP6 core patch. The build script applies the scheduler patch idempotently, compiles the Windows frontend plus headless/unit-test targets, runs the upstream unit tests, and packages the result as `dist/PSP6.exe`. This environment has not run the Windows GCC build, so the first compile and test result must be confirmed on the target PC.

## Updating upstream

Review upstream changes first, then deliberately update the submodule revision. Avoid blindly tracking a moving branch in production builds.
