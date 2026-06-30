# Why pure Go

`go-ruby-logger/logger` reimplements the deterministic core of Ruby's stdlib
`Logger` in **pure Go, with cgo disabled**. The slice of `Logger` it covers is
**deterministic and interpreter-independent**: which bytes a log line is, whether
a message is gated out by the level, and whether — and to what filename — a log
file should rotate are all pure functions of their inputs (an injected clock, pid
and filesize). That is exactly the part that can — and should — live as a
standalone Go library, separate from the interpreter and from the IO device.

## Compute core, host IO

The library never touches a file or the wall clock. It:

- **builds the line bytes** — the default `"%.1s, [%s #%d] %5s -- %s: %s\n"`
  format with the `%6N` timestamp and the `msg2str` coercion, over an **injected**
  clock and pid;
- **decides the severity gate** — `Add` formats nothing when `severity < level`
  or there is no sink;
- **computes the rotation plan** — whether to rotate (by size or by
  daily/weekly/monthly period) and the exact rename sequence / rotated-file names.

Opening the file, writing those bytes, performing the renames, and reading the
live wall clock are the **host's** job. The library hands back the bytes and the
rename plan; the host's IO device performs them.

## Extracted from rbgo, reusable by anyone

This library began life inside
[go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)'s `rbgo`. It has been
**extracted into a reusable standalone library** so that:

- any Go program can import `github.com/go-ruby-logger/logger` directly, with no
  Ruby runtime;
- the dependency runs the *other* way — `rbgo` binds this module as a native
  module (the same pattern as [go-ruby-regexp](https://github.com/go-ruby-regexp),
  [go-ruby-erb](https://github.com/go-ruby-erb) and
  [go-ruby-yaml](https://github.com/go-ruby-yaml)), rather than this module
  depending on the interpreter;
- the behaviour is pinned by a **differential oracle** against the system `ruby`,
  independent of any one consumer.

## Why pure Go matters here

Because the library is CGO-free and dependency-free, it:

- cross-compiles to every Go target with no C toolchain, and links into a single
  static binary;
- has **no dependency on the Ruby runtime** — the dependency runs the other way;
- can be differentially tested against the `ruby` binary wherever one is on
  `PATH`, while the cross-arch lanes (where `ruby` is absent) still validate the
  library itself.

See [Usage & API](api.md) for the surface and [Roadmap](roadmap.md) for what is
in scope.
