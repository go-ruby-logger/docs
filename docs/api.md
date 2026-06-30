# Usage & API

The public API lives at the module root (`github.com/go-ruby-logger/logger`). It
is **Ruby-shaped but Go-idiomatic**: the `Logger` type and its `Debug`/`Info`/… 
helpers mirror MRI's `Logger`, while the surface follows Go conventions —
injected seams (`Sink`, `Now`, `Pid`), value types, no global state.

!!! success "Status: implemented"
    The library is built and importable as `github.com/go-ruby-logger/logger`,
    bound into `rbgo` as a native module; see [Roadmap](roadmap.md).

## Install

```sh
go get github.com/go-ruby-logger/logger
```

## Worked example

```go
// The host wires the IO sink (here, stdout). The clock and pid default to the
// real ones; pass fixed ones for deterministic output.
log := logger.New(func(line string) { fmt.Print(line) })
log.Progname = "myapp"
log.Level = logger.INFO

log.Debug("filtered out (below INFO)", "")
log.Info("server started", "")
log.Warn("disk almost full", "")
// I, [2026-06-30T09:12:01.004212 #4242]  INFO -- myapp: server started
// W, [2026-06-30T09:12:01.004271 #4242]  WARN -- myapp: disk almost full
```

## Shape

```go
// Severity model (logger/severity.rb).
type Severity int
const (DEBUG Severity = 0; INFO; WARN; ERROR; FATAL; UNKNOWN) // 0..5
func SeverityLabel(s Severity) string            // "DEBUG".."FATAL", else "ANY"
func CoerceSeverity(v any) (Severity, error)     // int or "warn"/"FATAL"/…

// Formatter (logger/formatter.rb) — pure over injected clock + pid.
const DefaultDatetimeFormat = "%Y-%m-%dT%H:%M:%S.%6N"
type Inspector func(msg any) string              // host msg.inspect
type Exception struct { Message, Class string; Backtrace []string }
type Formatter struct { DatetimeFormat string; Inspect Inspector }
func (f *Formatter) Format(severityLabel string, t time.Time, pid int, progname string, msg any) string

// Logger (logger.rb) minus the IO device.
type Clock func() time.Time
type Logger struct {
	Level     Severity
	Progname  string
	Formatter *Formatter
	Sink      func(string) // the host IO device; nil = no device
	Now       Clock        // injected clock; defaults to time.Now
	Pid       func() int   // injected pid;   defaults to os.Getpid
}
func New(sink func(string)) *Logger
func (l *Logger) Add(severity Severity, message any, progname string) bool // alias Log
func (l *Logger) Write(msg string) int            // Logger#<< (raw, returns n or -1)
func (l *Logger) Debug/Info/Warn/Error/Fatal/Unknown(message any, progname string) bool
func (l *Logger) DebugQ/InfoQ/WarnQ/ErrorQ/FatalQ() bool
func (l *Logger) SetLevel(v any) error            // Logger#level=

// Rotation policy (logger/log_device.rb + logger/period.rb) — pure decisions.
type Period string // Daily, Weekly, Monthly, Now, Everytime
const (DefaultShiftSize = 1048576; DefaultShiftAge = 7; DefaultPeriodSuffix = "%Y%m%d")
func ShouldRotateBySize(currentSize, shiftSize int64, shiftAge int) bool
func ShouldRotateByPeriod(now, nextRotate time.Time) bool
type ShiftMove struct { From, To string }
func ShiftAgeSequence(filename string, shiftAge int) []ShiftMove
func PeriodAgeFile(filename string, periodEnd time.Time, periodSuffix string, exists func(string) bool) string
func NextRotateTime(now time.Time, period Period) (time.Time, error)
func PreviousPeriodEnd(now time.Time, period Period) (time.Time, error)
func ParsePeriod(s string) (Period, error)
```

## What rbgo binds (the sink stays host-side)

| Concern | Where it lives |
| --- | --- |
| Severity numbers + labels + coercion | **this library** |
| Default-format line bytes (`msg2str`, timestamp) | **this library** |
| Level gating (`Add` / predicates) | **this library** |
| Rotation *decision* + rename plan | **this library** |
| Wall clock / process id | host (injected via `Now`/`Pid`) |
| The IO device (open / write / rename) | host (the `Sink` + the renames) |

## MRI conformance

Correctness is defined by reference Ruby. A **differential oracle** generates the
default-format line, the `datetime_format` override, the `Exception` coercion,
end-to-end level gating, the full severity-label range and the
daily/weekly/monthly rotation schedule, and compares them **byte-for-byte**
against the system `ruby`. The oracle scripts stub `Process.pid` / `Time.now` to
fixed values so the bytes are stable, and skip themselves where `ruby` is absent
(e.g. the qemu arch lanes), so the cross-arch builds still validate the library.

## Relationship to Ruby

`go-ruby-logger/logger` is **standalone and reusable**, and is the logging
backend bound into [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)
by `rbgo` as a native module — the same way
[go-ruby-regexp](https://github.com/go-ruby-regexp),
[go-ruby-erb](https://github.com/go-ruby-erb) and
[go-ruby-yaml](https://github.com/go-ruby-yaml) are bound. The dependency runs
the other way: this library has no dependency on the Ruby runtime.
