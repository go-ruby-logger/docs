#!/usr/bin/env bash
#
# Copyright (c) the go-ruby-logger/logger authors
# SPDX-License-Identifier: BSD-3-Clause
#
# Library-level cross-runtime benchmark runner.
#
# Runs the SAME Logger#info workload through (a) the pure-Go go-ruby-logger
# library (benchmarks/go) and (b) each available reference Ruby runtime
# (benchmarks/ruby/logger.rb), then prints one Markdown table per sub-benchmark:
# ns/op and the ratio vs MRI. It also verifies that the deterministic part of
# each formatted line (severity/progname/message, with the "[<time> #<pid>]"
# field normalized away) is byte-identical between Go and MRI before trusting the
# numbers.
#
# Usage:  bash benchmarks/run.sh
# Env:    OUTER (timed passes, default 25), WARM (untimed passes, default 3),
#         RUBY / JRUBY / TRUFFLERUBY (override runtime binaries).
set -u
cd "$(dirname "$0")"

RUBY=${RUBY:-ruby}
JRUBY=${JRUBY:-jruby}
TRUFFLERUBY=${TRUFFLERUBY:-truffleruby}

RB=ruby/logger.rb
TMP=$(mktemp)
SMP=$(mktemp)
trap 'rm -f "$TMP" "$SMP"' EXIT

export GOWORK=off

run() { # <runtime-label> <cmd...>
  local label=$1; shift
  command -v "$1" >/dev/null 2>&1 || { echo "  ($label: $1 not found — skipped)" >&2; return; }
  echo "  $label ..." >&2
  "$@" 2>/dev/null | awk -F'\t' -v r="$label" '
    $1=="RESULT"{printf "%s\t%s\t%s\n", r, $2, $3}
    $1=="SAMPLE"{printf "%s\t%s\t%s\n", r, $2, $3 > "/dev/stderr"}' \
    2>>"$SMP" >> "$TMP"
}

echo "== go-ruby-logger library-level benchmark ==" >&2
echo "  go ..." >&2
( cd go && command -v go >/dev/null 2>&1 && go run . 2>/dev/null ) | awk -F'\t' '
  $1=="RESULT"{printf "go\t%s\t%s\n", $2, $3}
  $1=="SAMPLE"{printf "go\t%s\t%s\n", $2, $3 > "/dev/stderr"}' \
  2>>"$SMP" >> "$TMP"
run "mri"         "$RUBY"                "$RB"
run "mri-yjit"    "$RUBY" --yjit        "$RB"
run "jruby"       "$JRUBY"              "$RB"
run "truffleruby" "$TRUFFLERUBY"        "$RB"

# --- Byte-identity check: Go vs MRI on the deterministic part of each line. ---
echo >&2
echo "== byte-identity (deterministic parts, vs MRI) ==" >&2
identity_ok=1
for lbl in info-default info-custom; do
  g=$(awk -F'\t' -v l="$lbl" '$1=="go"&&$2==l{print $3}' "$SMP")
  m=$(awk -F'\t' -v l="$lbl" '$1=="mri"&&$2==l{print $3}' "$SMP")
  if [ -n "$g" ] && [ "$g" = "$m" ]; then
    echo "  $lbl: OK  ($g)" >&2
  else
    echo "  $lbl: MISMATCH  go=[$g] mri=[$m]" >&2
    identity_ok=0
  fi
done
[ "$identity_ok" = 1 ] || { echo "!! byte-identity failed — numbers not trustworthy" >&2; exit 1; }

echo >&2
# Emit one Markdown table per sub-benchmark (label), runtimes as rows.
awk -F'\t' '
  { key=$2; rt=$1; ns=$3; labels[key]=1; val[rt SUBSEP key]=ns; rts[rt]=1 }
  END {
    order="go mri mri-yjit jruby truffleruby"
    n=split(order, ord, " ")
    ln=0; for (k in labels) lab[++ln]=k
    for (i=1;i<=ln;i++) for (j=i+1;j<=ln;j++) if (lab[j]<lab[i]){t=lab[i];lab[i]=lab[j];lab[j]=t}
    for (i=1;i<=ln;i++){
      k=lab[i]
      printf "\n#### %s\n\n", k
      print  "| Runtime | ns/op | vs MRI |"
      print  "| --- | ---: | ---: |"
      base=val["mri" SUBSEP k]
      for (o=1;o<=n;o++){
        rt=ord[o]; v=val[rt SUBSEP k]
        if (v=="") continue
        ratio=(base!=""&&base+0>0)? sprintf("%.2f×", v/base) : "—"
        name=rt
        if (rt=="go") name="**go-ruby (pure Go)**"
        else if (rt=="mri") name="MRI"
        else if (rt=="mri-yjit") name="MRI + YJIT"
        else if (rt=="jruby") name="JRuby"
        else if (rt=="truffleruby") name="TruffleRuby"
        printf "| %s | %s | %s |\n", name, v, ratio
      }
    }
  }
' "$TMP"
