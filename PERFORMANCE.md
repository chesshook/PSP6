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
- Release compiler profile: GCC `-O3`, LTO, dead-section elimination, optional native CPU tuning, and static GCC/C++ runtime linking.
- Windows configuration selects the native Win32 frontend and skips the unnecessary SDL3 package requirement. Bundled zlib, PNG, FFmpeg, zstd, libchdr, libzip, and related dependencies are preferred over system DLL packages; Windows OS/API DLL imports remain expected.
- Floating-point semantics remain conservative; no fast-math.
- First PSP6 core patch: cache the event-queue tail in `Core/CoreTiming.cpp`. Monotonic/equal-time insertions now append in O(1); out-of-order insertions retain the original sorted scan. Equal-time FIFO ordering is preserved, removal paths maintain the cache, and save-state loading rebuilds it without changing the serialized format.
- Expected impact is limited to workloads that frequently schedule events at or after the current tail. No FPS or percentage gain is claimed before instrumented testing.

## Windows MinGW build correctness

- The Win32 GDI text drawer is selected for MinGW. The upstream Direct2D/DirectWrite drawer uses newer D2D/DirectWrite interfaces that are not consistently declared by MinGW-w64 SDK headers. MSVC/Windows builds retain the upstream modern drawer.
- Static libraries are assembled with GCC's LTO-aware `gcc-ar` and `gcc-ranlib`; plain `ar`/`ranlib` can emit "plugin needed to handle lto object" warnings and fail to preserve the intended LTO archive handling.
- These are build/toolchain compatibility fixes, not emulator-speed improvements. No speedup is claimed from them.

## Next performance engineering stages

1. **Establish a real baseline:** same PC, driver, game image, save state, rendering backend, resolution, frameskip, audio settings, and warm-up. Record emulation speed, median/p95 frame time, per-thread CPU time, GPU wait, audio underruns, and memory use.
2. **MIPS/JIT hot path:** sample real game workloads; inspect dispatcher exits, block lookup, IR lowering, register allocation/spills, memory helpers, and branch linking. Keep optimizations only when JIT comparison and game tests remain clean.
3. **GPU command path:** separate command decoding, vertex/index upload, driver submission, synchronization/readbacks, shader compilation, and texture-cache costs. Avoid trading accuracy for fewer draws.
4. **Memory and scheduler:** profile PSP memory mapping/fastmem, cache behavior, event scheduling and idle skipping. Preserve MMU/protection behavior, callback ordering, and savestates.
5. **Frame pacing/audio:** measure host waits and callback jitter separately from emulation time; optimize latency without allowing audio drift or frame pacing regressions.

A claimed "2x" result requires a repeatable before/after benchmark on the same game workload. Compiler flags alone do not establish it.

## Target performance profiles

- **Native (default):** `-march=native -mtune=native`; maximum host-CPU specialization, not intended for redistribution to older CPUs.
- **Portable:** set `PSP6_PORTABLE=1`; avoids native instruction-set selection while retaining normal Release/LTO optimization.
