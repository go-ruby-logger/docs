// SPDX-License-Identifier: BSD-3-Clause
//
// Library-level driver for the pure-Go go-ruby-logger/logger. It exercises the
// Ruby-visible Logger#info path — severity gate, default Formatter, buffer
// append — through the published Go API, so the ns/op is the library primitive's
// cost, isolated from the rbgo interpreter.
//
// The timestamp gotcha: a formatted line embeds the wall clock and the pid, so
// two processes never produce byte-identical lines. Both runtimes therefore run
// the *real* clock (each pays the Time.now + strftime cost, apples-to-apples),
// and cross-runtime byte-identity is checked on the deterministic remainder —
// severity, progname, message — after normalizing away the "[<time> #<pid>]"
// field (see sample()).
package main

import (
	"strings"

	"github.com/go-ruby-logger/logger"
)

// buf is a bounded, growing sink: appends model "logging to a buffer", and a
// reset caps memory without perturbing the amortized per-op cost. The same cap
// is applied on the Ruby side.
type buf struct{ b strings.Builder }

func (s *buf) write(line string) {
	if s.b.Len() > 1<<20 {
		s.b.Reset()
	}
	s.b.WriteString(line)
}

func main() {
	const (
		progname = "bench"
		message  = "user 4242 completed checkout in 128ms"
	)

	// Op 1: default formatter (DefaultDatetimeFormat "%Y-%m-%dT%H:%M:%S.%6N").
	var s1 buf
	def := logger.New(s1.write)
	def.Progname = progname

	// Op 2: custom formatter — a datetime_format override (second precision, no
	// fractional seconds), a different strftime path but the same emit shape.
	var s2 buf
	cust := logger.New(s2.write)
	cust.Progname = progname
	cust.Formatter = &logger.Formatter{DatetimeFormat: "%Y-%m-%d %H:%M:%S %z"}

	// Byte-identity samples (normalized), checked against MRI by run.sh.
	var one strings.Builder
	probe := logger.New(func(l string) { one.WriteString(l) })
	probe.Progname = progname
	probe.Info(message, "")
	sample("info-default", one.String())
	one.Reset()
	probe.Formatter = &logger.Formatter{DatetimeFormat: "%Y-%m-%d %H:%M:%S %z"}
	probe.Info(message, "")
	sample("info-custom", one.String())

	bench("info-default", 5000, func() { def.Info(message, "") })
	bench("info-custom", 5000, func() { cust.Info(message, "") })
	_ = sink
}
