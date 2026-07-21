// 食物图 → JSON（菜品+热量+营养+不内疚tags）
// 移植自 spec/CHA-PIAOLIANGFAN-001/m0-verify.py（M0 已验证通过）
// 与 RN 版 src/vision.ts 功能等价
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class Nutrition {
  final String dish;
  final int kcal;
  final num proteinG;
  final num carbG;
  final num fatG;
  final List<String> tags;

  Nutrition({
    required this.dish,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.tags,
  });

  factory Nutrition.fromJson(Map<String, dynamic> j) {
    final rawTags = j['tags'];
    List<String> tags;
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    } else {
      tags = [];
    }
    return Nutrition(
      dish: (j['dish'] ?? '').toString(),
      kcal: (j['kcal'] is num) ? (j['kcal'] as num).toInt() : int.tryParse(j['kcal']?.toString() ?? '0') ?? 0,
      proteinG: num.tryParse(j['protein_g']?.toString() ?? '0') ?? 0,
      carbG: num.tryParse(j['carb_g']?.toString() ?? '0') ?? 0,
      fatG: num.tryParse(j['fat_g']?.toString() ?? '0') ?? 0,
      tags: tags,
    );
  }
}

const String _prompt =
    '识别图中食物。估算这一份的：热量(kcal)、蛋白质(g)、碳水(g)、脂肪(g)、菜品名。再给3-5个"不内疚"话术tags(如 高蛋白/低脂/慢碳/富含纤维/优质脂肪/轻负担)。严格只输出JSON，不要任何其他文字：{"dish":"","kcal":0,"protein_g":0,"carb_g":0,"fat_g":0,"tags":[]}';

Future<Nutrition> recognizeFood(String imageBase64) async {
  final body = {
    'model': MinimaxConfig.model,
    // why: 杨总要"AI 返回结果稳定" — temperature=0 + seed 锁抽样到 argmax
    //      M3 vision 默认 temperature=1.0 会让 dish/kcal 浮动 (380/420/480 不一)
    'temperature': 0,
    'seed': 42,
    'messages': [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': _prompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
          },
        ],
      },
    ],
  };

  final res = await http.post(
    Uri.parse(MinimaxConfig.url),
    headers: {
      'Authorization': 'Bearer ${MinimaxConfig.key}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  if (res.statusCode != 200) {
    throw Exception('M3 error ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final choices = data['choices'];
  if (choices is! List || choices.isEmpty) {
    throw Exception('M3 no choices: ${res.body.substring(0, 200)}');
  }
  final msg = (choices[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>;
  // content 可能是 String 或 List
  final contentRaw = msg['content'];
  String content;
  if (contentRaw is String) {
    content = contentRaw;
  } else if (contentRaw is List) {
    // 拼接所有 text 段
    final buf = StringBuffer();
    for (final part in contentRaw) {
      if (part is Map && part['type'] == 'text') {
        buf.write(part['text'] ?? '');
      }
    }
    content = buf.toString();
  } else {
    content = contentRaw?.toString() ?? '';
  }

  // M3 输出 <think>...</think> + ```json {...} ```，提取 json block
  final fenced = RegExp(r'```json\s*([\s\S]*?)```').firstMatch(content);
  String jsonStr;
  if (fenced != null) {
    jsonStr = fenced.group(1)!;
  } else {
    // 去 think + 去 markdown 普通代码块
    jsonStr = content
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll(RegExp(r'```'), '')
        .trim();
  }

  // 兜底：抓第一个 {...}
  final brace = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
  if (brace != null) {
    jsonStr = brace.group(0)!;
  }

  final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
  return Nutrition.fromJson(parsed);
}
