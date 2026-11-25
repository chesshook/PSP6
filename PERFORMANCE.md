# PSP6 performance engineering

## Non-negotiable correctness rules

PSP6 remains a PSP emulator, not a benchmark-only renderer. Any change must preserve CPU-visible state, memory ordering, integer overflow behavior, VFPU precision, interrupt ordering, audio timing, and savestate compatibility.

Never enable `-ffast-math`, `-Ofast`, unsafe aliasing assumptions, or approximate CPU emulation by default.

## Hot paths to measure

1. **MIPS CPU execution and JIT**
   - IR frontend/optimizer, block lookup, x64 code generation, register-cache pressure, branch exits, memory fast paths.
   - Compare JIT and interpreter results with the existing JIT harness and game test suite.
2. **GPU command processing**
   - Display-list dispatch, state-dirty tracking, vertex decoding, draw batching, texture cache, framebuffer readbacks and synchronization.
   - Separate CPU submission time from GPU execution/wait time.
3. **Core scheduling**
   - Event insertion/removal, slice sizing, idle skipping and inter-CPU catch-up.
   - Preserve FIFO order for events with identical emulated timestamps and exact callback lateness.
4. **Audio**
   - Resampler/mixer CPU time, callback wakeups, buffer underruns and end-to-end latency.
5. **Presentation and UI**
   - Frame pacing, vsync waits, redundant layout/draw work, file-browser scanning, image decoding and texture upload stalls.

## Optimization workflow

For each patch:

1. Capture a baseline on the same machine, same build type, game, scene, settings and warm-up.
2. Record median and 95th-percentile frame time, emulation speed, CPU thread time, GPU wait time, audio underruns and memory use.
3. Change one bottleneck at a time.
4. Run unit tests, JIT comparison tests and affected game/graphics tests.
5. Repeat the benchmark; keep the patch only when the gain exceeds measurement noise and there is no correctness regression.
6. Document the measured hardware, game, build flags and before/after results.

## Current optimization baseline

- Pinned upstream: PPSSPP master revision `ee4594feff26e6a5c0bc2accfed19e9c5c117083`.
- Release compiler profile: GCC `-O3`, LTO, dead-section elimination, and optional native CPU tuning.
- Floating-point semantics remain conservative; no fast-math.
- PSP6-specific emulator-core changes are not yet applied. The first step establishes a reproducible source and build baseline so subsequent core patches can be measured and bisected safely.

## Target performance profiles

- **Native (default):** `-march=native -mtune=native`; maximum host-CPU specialization, not intended for redistribution to older CPUs.
- **Portable:** set `PSP6_PORTABLE=1`; avoids native instruction-set selection while retaining normal Release/LTO optimization.
