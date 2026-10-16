# Benchmarks Game — Uya Ports

Uya ports of programs from [The Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/).

## Programs

| Program | Uya file | Reference C | Notes |
|---------|----------|-------------|-------|
| [n-body](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/nbody.html) | `nbody.uya` | Orbital simulation, f64 math | 5 bodies, default 1000 steps |
| [spectral-norm](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/spectralnorm.html) | `spectralnorm.uya` | Matrix spectral norm, f64 math | Default n=2000, 10 iterations |
| [binary-trees](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/binarytrees.html) | `binarytrees.uya` | Recursive tree allocation/checksum | Default depth = min+2 |

## Build & Run

```sh
# Compile with Uya (C99 backend)
bin/uya build benchmarks/benchmarksgame/nbody.uya -o nbody

# Run with argument
./nbody 50000000
```

Or run directly via `bin/uya run`:

```sh
bin/uya run benchmarks/benchmarksgame/nbody.uya -- 50000000
```

## Verification Results

All three Uya ports produce **bit-identical output** to their C reference implementations:

| Program | Uya Output | C Reference Output | Match |
|---------|-----------|-------------------|-------|
| n-body (1000 steps) | `-0.169075164 / -0.169087605` | Same | ✅ |
| spectral-norm (n=2000) | `1.123046373` | Same | ✅ |
| binary-trees (depth 21) | check values match | Same | ✅ |

## Performance Notes

Measured on Linux x86-64, 50M simulation steps (`nbody`), 2000x2000 (`spectral-norm`), depth 21 (`binary-trees`).

- `nbody`: Uya default build ≈ 24.5s vs C reference ≈ 6.9s (~3.5×). Root cause: hosted builds define Uya's
  Newton-iteration `sqrt` (from `lib/libc/math.uya`) under the bare libc name, and the default `-fno-builtin`
  prevents GCC from emitting hardware `sqrtsd`. Experiment: delegating `sqrt` to the host libm lowers the
  same generated C to ≈ 8.7s; hosting standard math functions in hosted mode is the recommended next step.
- `spectral-norm`: Uya matches C (~0.26s for n=2000).
- `binary-trees`: Uya matches C (~23s for depth 21), dominated by `malloc`/`free` overhead.

## Optimization History

- `-O0` → `-O2` for the C99 backend (commit `6c90874c`); `-O2` builds auto-append
  `-fno-inline-small-functions` to dodge a known GCC small-function inlining miscompile.

## Source References

- C gcc #6: `program/nbody-gcc-6.html`
- C gcc #3: `program/spectralnorm-gcc-3.html`
- C gcc #3: `program/binarytrees-gcc-3.html`

Programs sourced from the Benchmarks Game (3-Clause BSD).
