#!/usr/bin/env bash
# The difference with groovyc alone, no build tool involved: compiles all classes together, then compiles
# Svc against the other classes compiled. Uses groovyc from the PATH, or the command in
# the GROOVYC environment variable.
set -euo pipefail
cd "$(dirname "$0")"
GROOVYC=${GROOVYC:-groovyc}
command -v "${GROOVYC%% *}" > /dev/null || { echo "groovyc not found; put it on the PATH or set GROOVYC"; exit 1; }

SRC=src/main/groovy/example
OUT=build/groovyc
rm -rf "$OUT"
mkdir -p "$OUT/together" "$OUT/first" "$OUT/second"

show() {
    local out
    out=$(javap -c -p "$1" | grep -E 'invoke(virtual|interface).*(set|get)Name' | sed -E 's/#[0-9]+(, *[0-9]+)?//; s/ +/ /g' || true)
    if [ -n "$out" ]; then echo "$out"; else echo "  (none)"; fi
}

echo "== all classes compiled together"
$GROOVYC -d "$OUT/together" "$SRC/Named.groovy" "$SRC/Base.groovy" "$SRC/Impl.groovy" "$SRC/Util.groovy" "$SRC/Svc.groovy"
echo "== Svc compiled against the other classes compiled"
$GROOVYC -d "$OUT/first" "$SRC/Named.groovy" "$SRC/Base.groovy" "$SRC/Impl.groovy" "$SRC/Util.groovy"
$GROOVYC -d "$OUT/second" -cp "$OUT/first" "$SRC/Svc.groovy"

echo
echo "== name accessor calls of Svc.rename, compiled together:"
show "$OUT/together/example/Svc.class"
echo "== name accessor calls of Svc.rename, compiled against the other classes:"
show "$OUT/second/example/Svc.class"
