// 卡路里标签 — editorial 手写贴纸感（walkup "Aurora Dawn Editorial" 调性对齐）
// why: 反 AI 模板感 = 暖渐变非冷白(A4) + 克制三色(B 色彩) + editorial 三级层级(D6)
//      + 手作"略微不齐"倾斜(A5) + 贴纸物理感非工业 shadow(A3)
import 'package:flutter/material.dart';
import 'vision.dart';

class CalorieBadge extends StatelessWidget {
  final Nutrition n;
  const CalorieBadge({super.key, required this.n});

  @override
  Widget build(BuildContext context) {
    // 克制三色：macro 统一深棕数字，不分彩虹色（DON'T: 强调色滥用）
    final macros = [('蛋白', n.proteinG), ('碳水', n.carbG), ('脂肪', n.fatG)];
    return Transform.rotate(
      angle: -0.015, // why: 手作"略微不齐"，破规整居中模板感(A5)
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          // sunrise 暖渐变替代冷白面板 —— "not the dead white of stock UI"(A4)
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF3E8), Color(0xFFFFE0C2)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3D2817), width: 1.5),
          // 贴纸物理感：轻 offset + 低 opacity，非工业重 shadow(A3)
          boxShadow: const [
            BoxShadow(color: Color(0x143D2817), blurRadius: 14, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // eyebrow —— editorial 杂志级小字(D6)
            const Text(
              'PRETTY MEAL · 不内疚',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB8927A),
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 6),
            // hero 数字 —— 主角，厚重深棕(克制，强调色让给 tags)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${n.kcal}',
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3D2817),
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('kcal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFB8927A))),
              ],
            ),
            const SizedBox(height: 4),
            // subtitle —— 菜品名
            Text(
              n.dish,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5A3F2E)),
            ),
            const SizedBox(height: 10),
            // macro —— editorial 表格感，统一深棕 + 细竖线分隔，非彩虹 chip
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < macros.length; i++) ...[
                    Expanded(
                      child: _macro(macros[i].$1, macros[i].$2),
                    ),
                    if (i < macros.length - 1)
                      const VerticalDivider(width: 1, color: Color(0x333D2817), indent: 2, endIndent: 2),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // tags —— 唯一强调色(莓果粉)，手写贴纸 pill(D3)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: n.tags.map((t) => _tag(t)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macro(String label, num g) {
    return Column(
      children: [
        Text(
          '${g}g',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3D2817),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFB8927A), letterSpacing: 0.5)),
      ],
    );
  }

  Widget _tag(String t) {
    return Transform.rotate(
      angle: t.hashCode.isEven ? 0.04 : -0.03, // why: tags 错落不齐，手贴感(A5)
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5C8A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '# $t',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
