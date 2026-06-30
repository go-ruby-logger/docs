# go-ruby-logger documentation

**The deterministic core of Ruby's stdlib `Logger` in pure Go — MRI-compatible, no cgo.**

`go-ruby-logger/logger` is a faithful, pure-Go (zero cgo) reimplementation of the
deterministic core of MRI 4.0.5's stdlib
[`Logger`](https://docs.ruby-lang.org/en/master/Logger.html) (the `logger-1.7.0`
gem): the severity model, the default `Logger::Formatter`, level gating, and the
`LogDevice` rotation **policy**. The module path is
`github.com/go-ruby-logger/logger`.

It was **extracted from rbgo's internals into a reusable standalone library**: the
module is standalone and importable by any Go program, and it is the logging
backend bound into [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)
by `rbgo` as a native module — just like
[go-ruby-regexp](https://github.com/go-ruby-regexp),
[go-ruby-erb](https://github.com/go-ruby-erb) and
[go-ruby-yaml](https://github.com/go-ruby-yaml). The dependency runs the other
way: this library has **no dependency on the Ruby runtime**.

!!! success "Status: complete — Logger core, MRI byte-exact"
    The **severity model** (`DEBUG`..`UNKNOWN`, `SeverityLabel`, `CoerceSeverity`), the **default formatter** (`"%.1s, [%s #%d] %5s -- %s: %s\n"` with the `%6N` timestamp and `msg2str` coercion) over an injected clock and pid, **level gating** (`Add` plus the helpers and `DebugQ`..`FatalQ` predicates), and the **rotation policy** (size shifts and daily/weekly/monthly periods) — all pure, no IO. Validated by a **differential oracle** against the system `ruby` byte-for-byte, at 100% coverage, `gofmt` + `go vet` clean, CI green across the six 64-bit Go targets and three OSes.

## What it is — and isn't

Building a log line, deciding the severity gate, and computing the rotation
schedule and rotated-file names are fully deterministic and need **no
interpreter**, so they live here as pure Go. Opening the file, writing the bytes,
renaming on rotation, and reading the live wall clock are the **host's** job: the
library hands back the bytes and the rename plan, and the host's IO device
performs them — via an injected `Sink`, `Now` clock and `Pid`.

## Quick taste

```go
log := logger.New(func(line string) { fmt.Print(line) })
log.Progname = "myapp"
log.Level = logger.INFO

log.Debug("filtered out (below INFO)", "")
log.Info("server started", "")
// I, [2026-06-30T09:12:01.004212 #4242]  INFO -- myapp: server started

// Rotation is a pure decision the host acts on.
if logger.ShouldRotateBySize(fileSize(), logger.DefaultShiftSize, logger.DefaultShiftAge) {
    for _, mv := range logger.ShiftAgeSequence("app.log", logger.DefaultShiftAge) {
        os.Rename(mv.From, mv.To) // host performs the rename plan
    }
}
```

## Repositories

| Repo | What it is |
| --- | --- |
| [`logger`](https://github.com/go-ruby-logger/logger) | the library — Ruby's `Logger` core in pure Go |
| [`docs`](https://github.com/go-ruby-logger/docs) | this documentation site (MkDocs Material, versioned with mike) |
| [`go-ruby-logger.github.io`](https://github.com/go-ruby-logger/go-ruby-logger.github.io) | the organization landing page (Hugo) |
| [`brand`](https://github.com/go-ruby-logger/brand) | logo and brand assets |

## Principles

- **Pure Go, `CGO_ENABLED=0`** — trivial cross-compilation, a single static
  binary, no C toolchain.
- **MRI byte-exact.** Line bytes, severity labels and the rotation schedule match
  reference Ruby exactly, validated by a differential oracle against the `ruby`
  binary.
- **Compute core, not the IO device.** The library is a pure decision layer; the
  host performs the IO via an injected sink, clock and pid.
- **100% test coverage** is the target, enforced as a CI gate, across 6 arches
  and 3 OSes.

## Where to go next

- [Why pure Go](why.md) — why the deterministic slice of `Logger` lives as a
  standalone, interpreter-independent Go library.
- [Usage & API](api.md) — the public surface and worked examples.
- [Roadmap](roadmap.md) — what is done and what is host-side by design.

Source lives at [github.com/go-ruby-logger/logger](https://github.com/go-ruby-logger/logger).
