<!-- SPDX-License-Identifier: BSD-3-Clause -->
# `go-ruby-logger` library-level benchmark harness

Reproducible, cross-runtime benchmark of the **pure-Go `go-ruby-logger/logger`
library** against the reference Ruby runtimes (MRI, MRI + YJIT, JRuby,
TruffleRuby). It measures the **Ruby-visible `Logger#info` operation** — the
severity gate, the default `Formatter`, and the buffer append — isolated from the
rbgo interpreter, so the numbers answer: *is the pure-Go implementation as fast
as the reference runtime's own stdlib `logger`?*

## Layout

- `go/`            — self-contained Go driver; `go.mod` pins the published library
  by pseudo-version (no `replace`). `go/bench` (the built binary) is git-ignored.
- `ruby/logger.rb` — the equivalent workload; `ruby/_harness.rb` is the shared timer.
- `run.sh`         — runs every available runtime, verifies Go/MRI byte-identity,
  and prints one Markdown table per sub-benchmark (ns/op + ratio vs MRI).

## Run

```sh
bash benchmarks/run.sh
```

Environment knobs: `OUTER` (timed passes, default 25), `WARM` (untimed warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select runtime binaries.
`GOWORK=off` is forced so the pinned module version is what gets measured.

## Method

Each process runs `WARM` untimed passes (to let the JVM/GraalVM JITs warm up),
then `OUTER` timed passes of a fixed inner loop (5 000 `logger.info` calls),
timed with a monotonic clock; the **best** pass is reported as **ns/op**.
Interpreter start-up is outside the timed region. The Go driver and the Ruby
script log the **same** message/progname/severity to an in-memory buffer sink,
op-for-op.

### The timestamp gotcha

A formatted log line embeds the wall clock **and** the process id
(`I, [2026-07-03T12:34:56.123456 #4242]  INFO -- prog: msg`), so two processes
never produce byte-identical lines. Both runtimes therefore run the **real**
clock — each pays the `Time.now` + `strftime` cost, apples-to-apples — and the
harness verifies byte-identity on the **deterministic remainder** (severity,
progname, message) after normalizing the `[<time> #<pid>]` field to `[T]`. If Go
and MRI disagree on that remainder, `run.sh` aborts before printing any numbers.

Two ops are measured:

- **`info-default`** — the default formatter (`%Y-%m-%dT%H:%M:%S.%6N` timestamp).
- **`info-custom`** — a custom `datetime_format` override (second precision), a
  different `strftime` path with the same emit shape.

Results are published, dated, in `../docs/performance.md`.
