#!/usr/bin/env bash
# 漂亮饭 BDD runner · 跑两端 Maestro flow + 收集截图 + 打 benchmark
# 套 bdd-loop-harness-verify-cycle：runner ≤100 行
# 用法: bash run_bdd.sh [flutter|rn|both]
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BDD="$SPEC_DIR/bdd"
OUT="$BDD/runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

export JAVA_HOME="$HOME/.local/jdk21/Contents/Home"
export PATH="$HOME/.maestro/bin:$JAVA_HOME/bin:$PATH"

TARGET="${1:-both}"
run_one() {
  local name="$1" flow="$2"
  echo "=== [$name] 跑 Maestro flow ==="
  if ! maestro test "$flow" --format junit -o "$OUT/$name-report.xml" \
        --output "$OUT/$name-screenshots" 2>&1 | tee "$OUT/$name.log"; then
    echo "⚠️ [$name] flow 失败，看 $OUT/$name.log（selector/picker 常需调）"
  fi
}

case "$TARGET" in
  flutter) run_one flutter "$BDD/maestro/flow-flutter.yaml" ;;
  rn)      run_one rn "$BDD/maestro/flow-rn.yaml" ;;
  both)    run_one flutter "$BDD/maestro/flow-flutter.yaml"
           run_one rn "$BDD/maestro/flow-rn.yaml" ;;
  *) echo "用法: $0 [flutter|rn|both]"; exit 1 ;;
esac

echo ""
echo "=== benchmark 产出 ==="
echo "截图/JUnit/log 全在: $OUT"
ls -la "$OUT" 2>/dev/null
echo ""
echo "下一步: 肉眼比 flutter-03-result vs rn-03-result 的图文编排炫感（视觉主观，agent 看图不可靠）"
