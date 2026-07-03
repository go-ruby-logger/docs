# frozen_string_literal: true
# SPDX-License-Identifier: BSD-3-Clause
#
# Reference workload: the same Logger#info path the pure-Go library ports, run
# through each interpreter's own stdlib `logger`. Measures the Ruby-visible
# operation (severity gate + default Formatter + buffer append), matched
# op-for-op to benchmarks/go/main.go.
require "logger"
require_relative "_harness"

PROGNAME = "bench"
MESSAGE  = "user 4242 completed checkout in 128ms"

# Bounded, growing sink: appends model "logging to a buffer", and a reset caps
# memory without perturbing the amortized per-op cost. Mirrors the Go driver's
# buf. A plain IO-like object (write/close) is all Logger requires.
class Buf
  def initialize
    @s = +""
  end

  def write(x)
    @s.clear if @s.bytesize > (1 << 20)
    @s << x
    x.bytesize
  end

  def close; end
end

# Op 1: default formatter (DatetimeFormat "%Y-%m-%dT%H:%M:%S.%6N" equivalent).
def_logger = Logger.new(Buf.new)
def_logger.progname = PROGNAME

# Op 2: custom formatter — a datetime_format override (second precision), a
# different strftime path but the same emit shape.
cust_logger = Logger.new(Buf.new)
cust_logger.progname = PROGNAME
cust_logger.datetime_format = "%Y-%m-%d %H:%M:%S %z"

# Byte-identity samples (normalized), checked against the Go driver by run.sh.
class Cap
  attr_reader :last
  def write(x)
    @last = x
    x.bytesize
  end

  def close; end
end

cap = Cap.new
probe = Logger.new(cap)
probe.progname = PROGNAME
probe.info(MESSAGE)
sample("info-default", cap.last)
probe.datetime_format = "%Y-%m-%d %H:%M:%S %z"
probe.info(MESSAGE)
sample("info-custom", cap.last)

bench("info-default", 5000) { def_logger.info(MESSAGE) }
bench("info-custom", 5000) { cust_logger.info(MESSAGE) }
