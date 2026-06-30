# Performance

`go-ruby-logger/logger` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's stdlib
`Logger`. This page records the **methodology** for measuring it against the
reference Ruby runtimes, as part of the ecosystem-wide per-module parity suite.

!!! note "No numbers are published here yet"
    This page documents *how* the comparison is run, not a result table. Numbers
    are only added once they have been measured on the host described below and
    checked byte-identical to MRI — never estimated or filled in from memory.

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
