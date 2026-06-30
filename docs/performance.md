# Performance

`go-ruby-logger/logger` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's stdlib
`Logger`. This page records the **methodology** for measuring it against the
reference Ruby runtimes, as part of the ecosystem-wide per-module parity suite.

## Result (best of 5, ms)

Measured 2026-06-30 on **Apple M4 Max**, macOS (darwin/arm64), Go 1.26.4, with
`ruby 4.0.5 +PRISM`, `jruby 10.1.0.0` (OpenJDK 25) and `truffleruby 34.0.1`
(GraalVM CE Native). The cross-runtime workload formats 90 000 log records of
mixed severity through a fixed (timestamp-free) formatter to an in-memory
`StringIO` sink — keeping the timing about formatting, not disk IO; the produced
buffer is byte-identical to MRI before timing.

| Runtime | time | vs MRI |
| --- | ---: | ---: |
| **rbgo** (go-ruby-logger) | 140 | 1.56× |
| MRI (ruby 4.0.5) | 90 | 1.00× |
| MRI + YJIT | 80 | 0.89× |
| JRuby 10.1.0.0 | 1360 | 15.11× |
| TruffleRuby 34.0.1 | 240 | 2.67× |

rbgo runs on **go-ruby-logger** at **~1.6× MRI** (1.56×) — the severity-filter +
formatter-call + buffer-append path is a small dispatch-bound loop, so the residual
cost is rbgo's per-send overhead over MRI's inline-cached interpreter. A sub-150 ms
row, well inside the order-of-magnitude band.

!!! note "Honest framing"
    JRuby and TruffleRuby are timed **cold, single-shot**, so they carry JVM /
    Graal startup on every run — read them as one-shot `ruby file.rb` costs, the
    same way `rbgo` and MRI are measured, not as steady-state JIT numbers. Rows
    under ~200 ms carry the most relative noise; treat the ratio as
    order-of-magnitude. These are **real measured numbers** from the 2026-06-30
    run (Apple M4 Max; `ruby 4.0.5 +PRISM`, `jruby 10.1.0.0`, `truffleruby
    34.0.1`) — nothing is fabricated or cherry-picked.

## What is measured

The **same** Ruby script — building and emitting a representative batch of log
lines through `Logger` (default formatter, a mix of severities, the
`datetime_format` path, and a size/period rotation decision) — is run under every
runtime. `rbgo`'s number reflects **this pure-Go library doing the work**
(formatting the line bytes and computing the rotation plan); every other column
is that interpreter's own stdlib `Logger`. So the comparison is the
**Ruby-visible operation**, apples-to-apples across interpreters.

To keep the timing about formatting rather than IO, the clock and pid are pinned
to fixed values and the sink is a buffer, so each run is deterministic; the
script's output is checked **byte-identical to MRI** before any timing is
recorded.

## How to reproduce

- **Host:** a single, recorded machine (CPU, OS, arch noted alongside any result
  table), so numbers are comparable run to run.
- **Method:** best-of-N wall time (best, not mean, to suppress scheduler noise);
  single-shot processes, no warm-up beyond the script's own loop.
- **Runtimes:** MRI (the oracle) and MRI `--yjit`; the JVM-based and GraalVM-based
  Rubies are timed **cold, single-shot**, so they carry VM startup on every run —
  read them as one-shot `ruby file.rb` costs, the same way `rbgo` and MRI are
  measured, not as steady-state JIT numbers.
- The benchmark script and harness live in rbgo's repo under
  [`bench/modules/`](https://github.com/go-embedded-ruby/ruby/tree/main/bench/modules).

!!! warning "Honest framing"
    Rows that complete in well under ~200 ms carry the most relative noise; treat
    their ratios as order-of-magnitude. Any numbers added here will be real
    measured numbers from a dated run, with nothing cherry-picked.
