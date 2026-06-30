# Contributing

Contributions are welcome. `go-ruby-logger/logger` is built to a small set of
non-negotiable rules — they are what keep it pure-Go, correct, and
MRI-compatible. Please read these before opening a pull request.

## Hard rules

- **Build from source — no vendoring.** Everything compiles from source. Being
  able to compile from source is a guarantee of independence.
- **100% test coverage target, enforced in CI.** New code ships with tests, and
  coverage is a CI gate. Fill the error branches, not just the happy path.
- **All GitHub content in English.** Issues, pull requests, commits, comments,
  and discussions are English-only.
- **Differential testing against MRI.** Correctness is defined by reference Ruby.
  The line bytes, the severity range and the rotation schedule are generated here
  and compared byte-for-byte against the system `ruby` — not approximated from
  memory.
- **Pure Go, cgo disabled.** The whole point is a single static binary with no C
  toolchain. Code must build with `CGO_ENABLED=0`. If a feature seems to need C,
  it needs a pure-Go path instead.
- **Compute core, not the IO device.** This module implements the deterministic
  decisions — the line bytes and the rename plan. Opening files, writing bytes,
  renaming and reading the live clock belong in the host, behind the `Sink`,
  `Now` and `Pid` seams.

## Workflow

1. Pick or open an issue describing the change.
2. Work test-first: add the differential / unit tests, then make them pass.
3. Run the full suite with coverage and confirm the gate is green:

    ```sh
    COVERPKG=$(go list ./... | paste -sd, -)
    go test -race -coverpkg="$COVERPKG" -coverprofile=cover.out ./...
    go tool cover -func=cover.out | tail -1   # 100.0%
    ```

4. Open a PR in English, referencing the issue.

## Where things live

The library is in
[`github.com/go-ruby-logger/logger`](https://github.com/go-ruby-logger/logger).
This documentation site is in
[`github.com/go-ruby-logger/docs`](https://github.com/go-ruby-logger/docs). Start
from the [Usage & API](api.md) page and the [Roadmap](roadmap.md) to find the
right place for your change.
