#!/bin/bash
# amalgame-formats-protobuf — test runner (self-contained: amc + libgc;
# node optional, for the proto-gen codegen round-trip).
set -u
PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AMC=""
if   [ -n "${1:-}" ];                   then AMC="$1"
elif command -v amc >/dev/null 2>&1;    then AMC="$(command -v amc)"
elif [ -x "$PKG_DIR/../Amalgame/amc" ]; then AMC="$PKG_DIR/../Amalgame/amc"
elif [ -x "$HOME/.local/bin/amc" ];     then AMC="$HOME/.local/bin/amc"
fi
[ -x "$AMC" ] || { echo "error: amc not found"; exit 2; }
RUNTIME_DIR=""
if   [ -n "${AMC_RUNTIME:-}" ] && [ -d "$AMC_RUNTIME" ]; then RUNTIME_DIR="$AMC_RUNTIME"
elif [ -d "$PKG_DIR/../Amalgame/runtime" ];             then RUNTIME_DIR="$PKG_DIR/../Amalgame/runtime"
elif [ -d "$HOME/.amalgame/runtime" ];                  then RUNTIME_DIR="$HOME/.amalgame/runtime"
fi
BUILD_DIR=$(mktemp -d); trap 'rm -rf "$BUILD_DIR"' EXIT
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
cd "$PKG_DIR"
INC="-Iruntime -I$RUNTIME_DIR"

# ── facade + codec unit tests ─────────────────────────────────────
"$AMC" --lib -o "$BUILD_DIR/facade" facade.am >/dev/null 2>&1
gcc -O2 $INC -c "$BUILD_DIR/facade.c" -o "$BUILD_DIR/facade.o" 2>"$BUILD_DIR/e" \
    || { echo -e "${RED}facade build failed${NC}"; cat "$BUILD_DIR/e"; exit 1; }
echo -e "\n── codec tests ──"
"$AMC" -o "$BUILD_DIR/t" tests/protobuf_test.am --external facade.am >/dev/null 2>&1
gcc -O2 $INC "$BUILD_DIR/t.c" "$BUILD_DIR/facade.o" -lgc -lm -o "$BUILD_DIR/t" 2>"$BUILD_DIR/e" \
    || { echo -e "${RED}test build failed${NC}"; cat "$BUILD_DIR/e"; exit 1; }
OUT="$("$BUILD_DIR/t")"; echo "$OUT"
echo "$OUT" | grep -q "\[FAIL\]" && { echo -e "${RED}FAILED${NC}"; exit 1; }

# ── codegen round-trip (proto-gen.js → AM classes) ────────────────
echo -e "\n── codegen round-trip ──"
if command -v node >/dev/null 2>&1; then
    node tools/proto-gen.js tests/sample.proto tests/sample_pb.am \
        || { echo -e "${RED}proto-gen failed${NC}"; exit 1; }
else
    echo "node not found — using the committed tests/sample_pb.am"
fi
# generated classes as a lib, then the round-trip test against it
"$AMC" --lib -o "$BUILD_DIR/sample" tests/sample_pb.am --external facade.am >/dev/null 2>&1
gcc -O2 $INC -c "$BUILD_DIR/sample.c" -o "$BUILD_DIR/sample.o" 2>"$BUILD_DIR/e" \
    || { echo -e "${RED}generated build failed${NC}"; cat "$BUILD_DIR/e"; exit 1; }
"$AMC" -o "$BUILD_DIR/cg" tests/codegen_test.am --external facade.am --external tests/sample_pb.am >/dev/null 2>&1
gcc -O2 $INC "$BUILD_DIR/cg.c" "$BUILD_DIR/sample.o" "$BUILD_DIR/facade.o" -lgc -lm -o "$BUILD_DIR/cg" 2>"$BUILD_DIR/e" \
    || { echo -e "${RED}codegen test build failed${NC}"; cat "$BUILD_DIR/e"; exit 1; }
OUT2="$("$BUILD_DIR/cg")"; echo "$OUT2"
echo "$OUT2" | grep -q "\[FAIL\]" && { echo -e "${RED}FAILED${NC}"; exit 1; }

echo -e "\n${GREEN}All tests passed${NC}"
