#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
haxe -cp src -cp tests -lib hscript -main RegressionChecks --interp
