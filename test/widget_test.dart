// 冒烟测试：app 能正常构建（漂亮饭 demo 无需 counter 测试）
import 'package:flutter_test/flutter_test.dart';
import 'package:piaoliangfan_flutter/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PiaoliangfanApp());
    expect(find.text('漂亮饭'), findsOneWidget);
    expect(find.text('选一张你的漂亮饭'), findsOneWidget);
  });
}
