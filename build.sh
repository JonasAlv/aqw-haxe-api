#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=> Compiling Haxe API..."
cd "$DIR"
npx haxe build.hxml

if [ -d "$DIR/../aqw-mobile-mod/loader/libs" ]; then
    cp "$DIR/bin/AqwApi.swc" "$DIR/../aqw-mobile-mod/loader/libs/AqwApi.swc"
    echo "=> Copied AqwApi.swc to aqw-mobile-mod/loader/libs/"
fi

echo "=> Haxe API Build Complete!"

