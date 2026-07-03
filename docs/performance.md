# Performance

`go-ruby-logger/logger` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's stdlib
`Logger`. This page records **real, dated, per-operation** measurements of the
library against the reference Ruby runtimes, as part of the ecosystem-wide
per-module parity suite.

## Setup

Measured **2026-07-03** on an **Apple M4 Max**, macOS (`darwin/arm64`). All
runtimes run natively on the host — no VM:

| Component | Version |
| --- | --- |
| Go | 1.26.4 |
| MRI | `ruby 4.0.5 (2026-05-20) +PRISM` |
| MRI + YJIT | same, `--yjit` |
| JRuby | `10.1.0.0` (OpenJDK 25) |
| TruffleRuby | `34.0.1` (GraalVM CE Native) |

Library pinned at `v0.0.0-20260630081511-870e2ee3f277`.

## What is measured

The **same** `Logger#info` workload — a severity gate, the `Formatter`, and an
append to an in-memory buffer sink — is run op-for-op through the pure-Go library
(via its Go API) and through each interpreter's own stdlib `logger`. So the
comparison is the **Ruby-visible operation**, apples-to-apples across
interpreters, not a synthetic microbenchmark.

Two ops:

- **`info-default`** — the default formatter (`%Y-%m-%dT%H:%M:%S.%6N` timestamp).
- **`info-custom`** — a custom `datetime_format` override (second precision) — a
  different `strftime` path with the same emit shape.

### Method

Each process runs 3 untimed warm-up passes (so the JVM/GraalVM JITs reach steady
state), then 25 timed passes of 5 000 `logger.info` calls each, timed with a
monotonic clock; the **best** pass is reported as **ns/op**. Interpreter
start-up is excluded from the timed region. The benchmark harness lives in this
repo under
[`benchmarks/`](https://github.com/go-ruby-logger/docs/tree/main/benchmarks).

### The timestamp gotcha, and how it is handled

A formatted line embeds the wall clock **and** the process id
(`I, [2026-07-03T12:34:56.123456 #4242]  INFO -- prog: msg`), so two processes
never emit byte-identical lines. Rather than fake the clock (which would hide the
real `Time.now` + `strftime` cost), **both runtimes run the real clock** — each
pays that cost, apples-to-apples — and the harness verifies byte-identity on the
**deterministic remainder** (severity, progname, message) after normalizing the
`[<time> #<pid>]` field to `[T]`. Verified equal, Go vs MRI, before any timing is
trusted:

```text
info-default: OK  (I, [T]  INFO -- bench: user 4242 completed checkout in 128ms)
info-custom:  OK  (I, [T]  INFO -- bench: user 4242 completed checkout in 128ms)
```

## Results (best-of-25, ns/op)

### `info-default`

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby-logger (pure Go)** | 397.6 | 0.31× |
| MRI (ruby 4.0.5) | 1303.2 | 1.00× |
| MRI + YJIT | 967.8 | 0.74× |
| JRuby 10.1.0.0 | 1214.1 | 0.93× |
| TruffleRuby 34.0.1 | 723.0 | 0.55× |

### `info-custom`

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby-logger (pure Go)** | 429.6 | 0.32× |
| MRI (ruby 4.0.5) | 1353.8 | 1.00× |
| MRI + YJIT | 978.2 | 0.72× |
| JRuby 10.1.0.0 | 1259.9 | 0.93× |
| TruffleRuby 34.0.1 | 1404.9 | 1.04× |

## go vs YJIT

**The pure-Go library beats MRI + YJIT on both ops**, by ~2.4×:

| Op | go-ruby-logger | MRI + YJIT | go ÷ YJIT |
| --- | ---: | ---: | ---: |
| `info-default` | 397.6 ns | 967.8 ns | **2.43× faster** |
| `info-custom` | 429.6 ns | 978.2 ns | **2.28× faster** |

It also beats plain MRI (~3.2×) and every other runtime on both ops. `Logger#info`
is a small dispatch-bound path — a level compare, one `sprintf`, a buffer append —
where Go's statically-compiled formatter and `strftime` have no interpreter
dispatch or `sprintf`-parsing overhead to pay, so the pure-Go implementation
comes out ahead even of YJIT's machine code.

!!! note "Cold-JIT caveat"
    JRuby and TruffleRuby are timed after only 3 warm-up passes in a single
    short-lived process, so they do **not** reach full steady-state JIT — read
    their rows as short-run costs, not peak throughput. TruffleRuby in particular
    swings run to run (0.55× on `info-default`, 1.04× on `info-custom` here);
    treat sub-microsecond ratios as order-of-magnitude. MRI, MRI + YJIT and the
    Go library are far more stable across runs. These are **real measured
    numbers** from the 2026-07-03 run on the host above — nothing is fabricated
    or cherry-picked.

## How to reproduce

```sh
git clone https://github.com/go-ruby-logger/docs
bash docs/benchmarks/run.sh
```

`run.sh` runs every runtime it can find, re-checks the Go/MRI byte-identity, and
re-emits the tables above. Knobs: `OUTER` (timed passes), `WARM` (warm-up
passes), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select binaries.
