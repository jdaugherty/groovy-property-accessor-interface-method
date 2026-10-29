#!/usr/bin/env bash
# Shows that an incremental build compiles Svc.groovy differently than a full build although it did not change.
# Restores the source it edits. Pass Gradle options through, for example: ./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT
set -euo pipefail
cd "$(dirname "$0")"

UTIL=src/main/groovy/example/Util.groovy
CLASS=build/classes/groovy/main/example/Svc.class
OUT=build/demo
show() {
    local out
    out=$(javap -c -p "$1" | grep -E 'invoke(virtual|interface).*(set|get)Name' | sed -E 's/#[0-9]+(, *[0-9]+)?//; s/ +/ /g' || true)
    if [ -n "$out" ]; then echo "$out"; else echo "  (none)"; fi
}

echo "== 1. Full build: all classes are compiled together"
./gradlew --console=plain -q "$@" clean classes
mkdir -p "$OUT"
cp "$CLASS" "$OUT/full.class"

echo
echo "== 2. Change a method body in Util, which Svc uses only inside a method body"
sed -i.bak "s/'loading'/'loading...'/" "$UTIL"
trap 'mv "$UTIL.bak" "$UTIL"' EXIT

echo
echo "== 3. Incremental build: Svc is recompiled against the other classes compiled"
./gradlew --console=plain --info "$@" classes | grep -E "Incremental compilation of|Full recompilation is required" || true
cp "$CLASS" "$OUT/incremental.class"

echo
echo "== 4. name accessor calls of Svc.rename, full build:"
show "$OUT/full.class"
echo "== name accessor calls of Svc.rename, incremental build:"
show "$OUT/incremental.class"
