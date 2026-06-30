# Roadmap

`go-ruby-logger/logger` is grown **test-first**, each capability
differential-tested against MRI rather than built in isolation. The deterministic
core of Ruby's `Logger` — the interpreter-independent slice extracted from rbgo's
internals — is **complete**.

| Stage | What | Status |
| --- | --- | --- |
| Severity model | `DEBUG=0 INFO=1 WARN=2 ERROR=3 FATAL=4 UNKNOWN=5`, the `SeverityLabel` mapping (`"DEBUG"`..`"FATAL"`, then `"ANY"`), and `CoerceSeverity` (MRI's `Severity.coerce` from an int or a `"warn"`/`"FATAL"` string). | **Done** |
| Default formatter | MRI's `"%.1s, [%s #%d] %5s -- %s: %s\n"` with the `"%Y-%m-%dT%H:%M:%S.%6N"` timestamp, the `datetime_format` override, and the `msg2str` coercion (`String` as-is, `Exception` → `"message (Class)\nbacktrace"`, else the host's `inspect`) — pure over an injected clock and pid. | **Done** |
| Level gating | `Add` (alias `Log`) returns `true` and formats nothing with no sink or `severity < level`; the `Debug`/`Info`/`Warn`/`Error`/`Fatal`/`Unknown` helpers, the `<<`-style raw `Write`, and the `DebugQ`..`FatalQ` predicates all mirror MRI. | **Done** |
| Rotation by size | For an integer `shift_age` + `shift_size`: `ShouldRotateBySize` and the `ShiftAgeSequence` rename plan. | **Done** |
| Rotation by period | For a calendar `shift_age` (`"daily"`/`"weekly"`/`"monthly"`, plus `"now"`/`"everytime"`): `NextRotateTime`, `PreviousPeriodEnd`, `ShouldRotateByPeriod`, and the `PeriodAgeFile` rotated-name with MRI's `.1`..`.99` collision suffix. | **Done** |
| Differential oracle & coverage | The line bytes, the `datetime_format` override, the `Exception` coercion, end-to-end gating, the full severity range and the rotation schedule compared byte-for-byte against the system `ruby`; 100% coverage, gofmt + go vet clean, green across all six 64-bit Go arches and three OSes. | **Done** |

## Documented out-of-scope boundaries

These are **deliberate**, recorded so the module's surface is unambiguous:

- **No IO device.** The library implements the deterministic decisions — the line
  bytes and the rename plan; it never opens a file, writes bytes or performs a
  rename. That is the host's job, wired through the `Sink`.
- **No live clock or pid.** The wall clock and process id are injected via `Now`
  and `Pid`; the library never reads them itself, which is what makes the output
  reproducible and testable.
- **No interpreter.** Anything that needs a live Ruby binding is the consumer's
  job — that is why `rbgo` binds this module rather than the reverse.
- **Reference is reference Ruby (MRI 4.0.5 / `logger-1.7.0`).** Byte-for-byte
  conformance targets that behaviour, pinned by the differential oracle.

See [Usage & API](api.md) for the surface and [Why pure Go](why.md) for the
compute-core / host-IO split.
