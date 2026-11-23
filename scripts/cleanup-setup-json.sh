#!/usr/bin/env bash
# Deletes Lake's per-module *.setup.json files that are more than 10 minutes old.
# Lean reads its setup file at startup, and Lake does not need it after the module
# is built (tested on a finished module: no rebuild, file not recreated).
# Without this, the files reached ~700 GB for this project.
#
# Usage (in a separate tmux session while `lake build` runs):
#   bash ~/rh/riemann-lean-check/scripts/cleanup-setup-json.sh [path-to-project]

PROJECT="${1:-$HOME/rh/lean}"

if [ ! -d "$PROJECT/.lake/build" ]; then
  echo "no .lake/build under $PROJECT" >&2
  exit 1
fi

while true; do
  if [ -d "$PROJECT/.lake/build/ir" ]; then
    find "$PROJECT/.lake/build/ir" -name '*.setup.json' -type f -mmin +10 -delete
  fi
  date
  df -h / | tail -1
  sleep 600
done
