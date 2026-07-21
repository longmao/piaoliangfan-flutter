#!/bin/bash
# 漂亮饭 BDD orchestrator · 跑 6 个 scenario + 验 business invariants
# Usage: bash run-all.sh [sim|real] [flutter|rn|both]
set -e
MODE="${1:-sim}"      # sim or real
APPS="${2:-both}"     # flutter, rn, or both
SIM_UDID="${SIM_UDID:-335D9D71-9A69-4507-8FD2-EC4D5B180E3C}"
REAL_UDID="${REAL_UDID:-00008101-000914AE11F9001E}"
DEVICE_UDID="$SIM_UDID"
[[ "$MODE" == "real" ]] && DEVICE_UDID="$REAL_UDID"

export JAVA_HOME="$HOME/.local/jdk21/Contents/Home"
export PATH="$HOME/.maestro/bin:$JAVA_HOME/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAESTRO_DIR="$(dirname "$SCRIPT_DIR")/maestro"
RESULTS_DIR="$SCRIPT_DIR/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

run_app() {
  local APP="$1"
  local PASS=0 FAIL=0
  echo ""
  echo "════════════════════════════════════════"
  echo "  $APP · $MODE · udid=$DEVICE_UDID"
  echo "════════════════════════════════════════"
  for s in s1-launch-network s2-pick-sample s3-preset-dazz s4-analyze-vision s5-share-image s6-vision-fail; do
    YAML="$MAESTRO_DIR/${s}-${APP}.yaml"
    [[ ! -f "$YAML" ]] && continue
    echo ""
    echo "── $s ──"
    if maestro test --device "$DEVICE_UDID" "$YAML" 2>&1 | tee "$RESULTS_DIR/${APP}-${s}.log" | tail -20; then
      [[ ${PIPESTATUS[0]} -eq 0 ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
    fi
  done
  echo ""
  echo "  $APP total: $PASS pass / $FAIL fail"
}

[[ "$APPS" == "flutter" || "$APPS" == "both" ]] && run_app flutter
[[ "$APPS" == "rn" || "$APPS" == "both" ]] && run_app rn

echo ""
echo "════════════════════════════════════════"
echo "  业务不变式 · 文件系统侧"
echo "════════════════════════════════════════"
APP_CONTAINER=$(xcrun simctl get_app_container $SIM_UDID com.vincent.plf.flutter data 2>/dev/null || echo "")
if [[ -n "$APP_CONTAINER" ]]; then
  PF="$APP_CONTAINER/tmp/pf_share.png"
  if [[ -f "$PF" ]]; then
    echo "Flutter pf_share.png: $(stat -f%z "$PF") bytes"
    bash "$SCRIPT_DIR/verify_business_invariants.sh" flutter "$APP_CONTAINER/tmp" 2>&1 | tail -15
  else
    echo "  Flutter pf_share.png not found at $PF (analyze+share flow 没跑到 share)"
  fi
fi
RN_CONTAINER=$(xcrun simctl get_app_container $SIM_UDID com.vincent.plf.rn data 2>/dev/null || echo "")
if [[ -n "$RN_CONTAINER" ]]; then
  echo ""
  echo "RN container: $RN_CONTAINER/tmp"
  ls -la "$RN_CONTAINER/tmp/" 2>&1 | tail -5
fi

echo ""
echo "Results: $RESULTS_DIR"