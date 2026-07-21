#!/bin/bash
# BDD 业务不变式机械验证脚本
# 来源：lib/vision.dart Nutrition schema + lib/presets.dart kPresets + lib/main.dart share text 格式
# 用法：bash verify_business_invariants.sh <flutter|rn> <app_container_tmp_dir>
set -e

KIND="$1"   # flutter 或 rn
TMP_DIR="$2"

echo "=== BDD 业务不变式自验 · $KIND ==="

# --- 业务不变式 1: share 图存在且非空 ---
SHARE_PNG=$(find "$TMP_DIR" -name "pf_share.png" 2>/dev/null | head -1)
if [[ -z "$SHARE_PNG" ]]; then
  echo "FAIL: pf_share.png not found in $TMP_DIR"
  exit 2
fi
SIZE=$(stat -f%z "$SHARE_PNG")
echo "  share.png size: $SIZE bytes"
if [[ $SIZE -lt 50000 ]]; then
  echo "FAIL: share.png too small ($SIZE < 50000) - 截图可能空白"
  exit 2
fi

# --- 业务不变式 2: share.png 含 CalorieBadge 色块 ---
# CalorieBadge 背景 #FFF1E6 = (255,241,230); tags chip 粉 #FF5C8A = (255,92,138)
# Preset overlay 暖白 #FFF1E6 (255,241,230) 也同色，所以检测 tags 粉
PINK_COUNT=$(python3.11 -c "
from PIL import Image
img = Image.open('$SHARE_PNG')
W,H = img.size
# tags chip 区域 = 底部 12% 中段 (bottom 12%, x 30%-70%)
bottom_start = int(H*0.85)
pink_count = 0
for y in range(bottom_start, H, 5):
    for x in range(int(W*0.3), int(W*0.7), 5):
        r,g,b,*_ = img.getpixel((x,y))
        if 240<=r<=255 and 70<=g<=110 and 120<=b<=160:
            pink_count += 1
print(pink_count)
")
echo "  tags-pink pixels: $PINK_COUNT"
if [[ $PINK_COUNT -lt 50 ]]; then
  echo "FAIL: share.png 不含 tags chip 粉 (=$PINK_COUNT), CalorieBadge 可能没进图"
  exit 2
fi

# --- 业务不变式 3: kcal 数字像素存在 ---
# 'kcal' 文字 = 棕色 #3D2817 (61,40,23); 大数字 '420' 是棕色
# 简化：检测 420 数字区域 (~12% 处，宽 ~30% 高 ~12%)
BROWN_COUNT=$(python3.11 -c "
from PIL import Image
img = Image.open('$SHARE_PNG')
W,H = img.size
# kcal 420 数字区域: x 5-35%, y 65-78% (放宽)
y_start, y_end = int(H*0.55), int(H*0.85)
brown_count = 0
for y in range(y_start, y_end, 2):
    for x in range(int(W*0.05), int(W*0.40), 2):
        r,g,b,*_ = img.getpixel((x,y))
        if 50<=r<=90 and 30<=g<=65 and 15<=b<=45:
            brown_count += 1
print(brown_count)
")
echo "  kcal-brown pixels: $BROWN_COUNT"
if [[ $BROWN_COUNT -lt 80 ]]; then
  echo "FAIL: share.png 不含 kcal 大数字棕 (=$BROWN_COUNT), 数字 420 可能没进图"
  exit 2
fi

# --- 业务不变式 4: Nutrition schema (vision API 返回字段完整) ---
# 通过 verify_nutrition.py 直接 call API 验
echo ""
echo "=== 业务不变式 4: Nutrition schema 直接调 API ==="
python3.11 "$(dirname "$0")/verify_nutrition.py"

echo ""
echo "✅ 全部业务不变式通过"