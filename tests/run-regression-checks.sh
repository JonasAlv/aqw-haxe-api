#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
haxe -cp src -cp tests -main RegressionChecks --interp
