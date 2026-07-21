# 漂亮饭 User Stories + 页面交互流 → BDD scenarios

> 来源：spec/CHA-PIAOLIANGFAN-001/CHARTER.md（让一顿饭值得发）+ lib/main.dart + App.tsx 业务代码
> 推导顺序：user story → 交互流 → 业务不变式 → BDD scenarios

---

## User Stories（6 条 · 杨总画像视角）

### US-1 · 我想挑一张我的饭图，让 app 自动算热量
**As a** 美食记录者  
**I want to** 上传一张食物照片  
**So that** 系统能识别菜品并估算这一份的热量+营养+不内疚话术

**交互**：首页空态 → tap "用示例图" 或 选图区 → 切到选图后态

### US-2 · 我想让图更好看（滤镜/胶片框），发出去不寒碜
**As a** 颜值党  
**I want to** 选一个美化预设（暖白/番茄橙/胶片框）  
**So that** 食物图有滤镜或胶片框装饰，发出去不掉价

**交互**：选图后态 → tap preset chip → preview 实时叠层

### US-3 · 我想让别人知道这顿值不值得吃
**As a** 健康焦虑者  
**I want to** AI 算出 kcal/蛋白/碳水/脂肪/不内疚 tags  
**So that** 看到「420kcal 高蛋白 轻负担」这种心安话术

**交互**：选图后态 → tap "AI 算这顿值不值得" → 等 5-10s → CalorieBadge 浮层浮现

### US-4 · 我想一键分享到小红书/朋友圈，不内疚话术自带
**As a** 社交分享者  
**I want to** tap 分享按钮 → 系统 share sheet → 选目标 app  
**So that** 分享出去的图 = 我看到的样子（带 CalorieBadge）+ 文字含 kcal/不内疚话术

**交互**：CalorieBadge 浮现态 → tap 分享 → iOS share sheet

### US-5 · 我想开 app 就能用，不想等 vision 网络冷启动
**As a** 急性子用户  
**I want to** app 一打开就后台 warm network（DNS+TLS 预热）  
**So that** tap "AI 算" 时不卡 2-3s 等握手

**交互**：启动 → 网络指示器 橙→绿 → _netReady=true

### US-6 · 我希望 vision 失败时不要卡死，给我退路
**As a** 容错敏感用户  
**I want to** AI 算失败时显示错误文案 + 重试按钮  
**So that** 网络差/图不清/模型挂时不至于空白卡住

**交互**：analyze 异常 → 错误文案 + "重新算这顿" 按钮

---

## 页面交互流（4 个状态 + 6 个 transition）

```
[启动 LaunchScreen] 🍱 "漂亮饭" "正在连接网络…"
        │
        ▼
[State 1: 空态] placeholder 选图区 + "用示例图" 钩子 + 网络指示器
   • tap "用示例图" (US-1)
   • tap placeholder (US-1) 走系统 PHPicker
        │
        ▼
[State 2: 选图后态] preview (无 badge) + preset row + AI 算 + 分享 disabled
   • tap preset chip (US-2) → 重新渲染 preview 叠层
   • tap "AI 算" (US-3)
        │
        ▼
[State 3: AI 加载中] preview + 「识别菜品」→「计算卡路里」→「生成「不内疚」标签」阶段文案
   • 5-10s 内 vision 返回 (成功 → State 4) (失败 → State 3.5)
        │
        ▼
[State 3.5: AI 失败] preview + 错误文案 + "重新算这顿" (US-6)
   • tap 重试 → State 3
        │
        ▼
[State 4: AI 完成态] preview + CalorieBadge 浮层 + 分享 enabled
   • tap 分享 (US-4) → 系统 share sheet
```

---

## BDD Scenarios（6 条 · 业务不变式）

### S-1: 启动到空态（US-5 · 网络预热）
**Given** app 启动  
**When** 用户等待 ≤5s  
**Then** 网络指示器由橙→绿 (_netReady=true)  
**And** 「漂亮饭」标题 + 「让一顿漂亮饭，变成值得发的内容」副标题可见  
**And** placeholder 选图区可见  
**And** 「用示例图（测试）」bypass 钩子可见

### S-2: 空态 → 选图后态（US-1）
**Given** 空态  
**When** tap "用示例图（测试）"  
**Then** preview 替换 placeholder，显示示例食物图 (甘虾虾)  
**And** preset row 显示 4 个 chip：原片 / 暖白 / 番茄橙 / 胶片框  
**And** "AI 算这顿值不值得" + "分享" 按钮出现（分享 disabled）

### S-3: preset 切换（US-2）
**Given** 选图后态  
**When** tap "胶片框"  
**Then** preset row 高亮「胶片框」chip  
**And** preview 显示胶片框装饰（白边 + 日期戳 "PIAOLIANGFAN · 2026.07.21"）

### S-4: AI 算 vision（US-3 · 业务不变式 · 6 字段）
**Given** 选图后态，preset 已选  
**When** tap "AI 算这顿值不值得"  
**Then** loading 文案按阶段切换：识别菜品 → 计算卡路里 → 生成「不内疚」标签  
**And** 5-10s 后 vision 返回  
**And** CalorieBadge 显示：dish (中文 ≥ 2 字) / kcal (100-2000 整数) / P-C-F (≥ 0 浮点) / tags (≥ 3 个 hashtag chip)  
**And** tips 文案显示 "💡 tags 就是你的「不内疚」话术，发出去不心虚"

### S-5: 分享（US-4 · 业务不变式 · 图含 badge + text 含字段）
**Given** AI 完成态  
**When** tap "分享"  
**Then** 触发 _share() → captureKey.toImage(pixelRatio:3.0) → pf_share.png 写盘  
**And** pf_share.png > 50KB 且含 CalorieBadge 像素（粉红 #FF5C8A tags chip + 棕 #3D2817 kcal 大数字）  
**And** share text 含：漂亮饭 / {kcal}kcal / {dish} / 蛋白/碳水/脂肪 / tags hashtag / "💡 不内疚，发出去不心虚"

### S-6: vision 失败（US-6 · 容错）
**Given** 选图后态  
**When** vision API 返回非 200 (断网/超时/key 错)  
**Then** 错误文案显示 "⚠️ M3 error ..."  
**And** "重新算这顿" 按钮可点  
**And** preview 仍正常渲染（不白屏）

---

## BDD YAML 编排

每个 scenario 拆独立 YAML（feature-like isolation），跑完输出 evidence：
- S-1 → `launch-and-network.yaml`
- S-2 → `pick-sample.yaml`
- S-3 → `select-preset-dazz.yaml`
- S-4 → `analyze-vision.yaml`
- S-5 → `share-image-content.yaml`
- S-6 → `analyze-fail-retry.yaml`

外加一个 orchestrator `run-all.sh`：按顺序跑 + 每步验 business invariants + 出 md 报告。