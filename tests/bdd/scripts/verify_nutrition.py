#!/usr/bin/env python3.11
# BDD 业务不变式 · Nutrition schema 验证
# 直接调 M3 vision API 验: dish/kcal/protein/carb/fat/tags 字段全 + 范围合理
# 为什么独立验证: app 内的 analyze() 失败可能是 UI bug, 不一定是 API bug
# spec source: lib/vision.dart Nutrition.fromJson + _prompt (3-5 tags)
import base64
import json
import os
import re
import sys
import urllib.request

API_URL = "https://api.minimaxi.com/v1/chat/completions"
API_KEY = os.environ.get("MINIMAX_API_KEY", os.environ.get("MINIMAX2_API_KEY", ""))
SAMPLE_JPG = "/Users/vincent/work/piaoliangfan-rn/assets/ganguoxia.jpg"

PROMPT = (
    '识别图中食物。估算这一份的：热量(kcal)、蛋白质(g)、碳水(g)、脂肪(g)、菜品名。'
    '再给3-5个"不内疚"话术tags(如 高蛋白/低脂/慢碳/富含纤维/优质脂肪/轻负担)。'
    '严格只输出JSON，不要任何其他文字：{"dish":"","kcal":0,"protein_g":0,"carb_g":0,"fat_g":0,"tags":[]}'
)


def call_vision():
    with open(SAMPLE_JPG, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("ascii")
    body = {
        "model": "MiniMax-Text-01",
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": PROMPT},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
            ],
        }],
    }
    req = urllib.request.Request(API_URL, method="POST", headers={
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }, data=json.dumps(body).encode())
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())


def extract(content):
    m = re.search(r"```json\s*([\s\S]*?)```", content)
    s = m.group(1) if m else re.sub(r"<think>[\s\S]*?</think>", "", content).strip()
    return json.loads(re.search(r"\{[\s\S]*\}", s).group(0))


def main():
    if not API_KEY:
        print("FAIL: MINIMAX_API_KEY 未设")
        sys.exit(2)

    print(f"call M3 vision API...")
    r = call_vision()
    content = r["choices"][0]["message"]["content"]
    n = extract(content)

    # 业务不变式: 6 字段全
    missing = [k for k in ("dish", "kcal", "protein_g", "carb_g", "fat_g", "tags") if k not in n]
    if missing:
        print(f"FAIL: missing fields {missing}; got {n}")
        sys.exit(2)

    # 业务不变式: kcal 合理范围 (一份饭 100-2000)
    if not (100 <= int(n["kcal"]) <= 2000):
        print(f"FAIL: kcal {n['kcal']} 不在 100-2000 范围")
        sys.exit(2)

    # 业务不变式: macros ≥ 0
    for k in ("protein_g", "carb_g", "fat_g"):
        if float(n[k]) < 0:
            print(f"FAIL: {k}={n[k]} < 0")
            sys.exit(2)

    # 业务不变式: tags ≥ 3 (杨总要"3-5 个不内疚话术")
    if not isinstance(n["tags"], list) or len(n["tags"]) < 3:
        print(f"FAIL: tags len={len(n.get('tags', []))} < 3 (杨总要 3-5 个)")
        sys.exit(2)

    # 业务不变式: dish 非空
    if not n["dish"] or len(n["dish"]) < 2:
        print(f"FAIL: dish='{n['dish']}' 太短")
        sys.exit(2)

    print(f"  dish: {n['dish']}")
    print(f"  kcal: {n['kcal']}")
    print(f"  P/C/F: {n['protein_g']}/{n['carb_g']}/{n['fat_g']} g")
    print(f"  tags ({len(n['tags'])}): {n['tags']}")
    print("✅ Nutrition schema 业务不变式全过")


if __name__ == "__main__":
    main()