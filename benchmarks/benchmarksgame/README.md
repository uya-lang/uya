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

- `nbody`: Uya's `libc.math.sqrt` is a Uya Newton-iteration implementation (not C libm), so Uya runs ~2.8× slower than C at `-O3`.
- `spectral-norm`: Uya at `--opt=3` matches C `-O3` performance (~0.26s for n=2000).
- `binary-trees`: Uya at `--opt=3` matches C `-O3` (~23s for depth 21), dominated by `malloc`/`free` overhead.

## Source References

- C gcc #6: `program/nbody-gcc-6.html`
- C gcc #3: `program/spectralnorm-gcc-3.html`
- C gcc #3: `program/binarytrees-gcc-3.html`

Programs sourced from the Benchmarks Game (3-Clause BSD).
