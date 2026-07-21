// 漂亮饭 Flutter demo · 核心流程：选图→美化预设→M3 vision 算热量→不内疚标签→分享
// spec: CHA-PIAOLIANGFAN-001 | 视觉: design-refs.md（暖白+番茄橙+胶片框+NutriAI 标签）
// 与 RN 版 App.tsx 功能等价
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import 'vision.dart';
import 'presets.dart';
import 'calorie_badge.dart';
import 'config.dart';

void main() {
  runApp(const PiaoliangfanApp());
}

class PiaoliangfanApp extends StatefulWidget {
  const PiaoliangfanApp({super.key});

  @override
  State<PiaoliangfanApp> createState() => _PiaoliangfanAppState();
}

class _PiaoliangfanAppState extends State<PiaoliangfanApp> {
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();

  @override
  void initState() {
    super.initState();
    // why: 真机 BDD 自验钩子 - devicectl openURL plf://auto → AppDelegate 写 bdd_trigger.txt
    // Flutter 端启动后读 NSTemporaryDirectory()/bdd_trigger.txt → host=auto 触发 autoRunShareFlow
    // 免 UI tap (真机 iOS 26.6 devicectl/idb/Maestro 全无 tap API 兜底)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 800));
      _checkBddTrigger();
    });
  }

  Future<void> _checkBddTrigger() async {
    try {
      final f = File('${Directory.systemTemp.path}/bdd_trigger.txt');
      if (!await f.exists()) return;
      final content = await f.readAsString();
      debugPrint('[BDD] trigger file: $content');
      // 删掉避免重复触发
      try { await f.delete(); } catch (_) {}
      if (content.contains('host=auto')) {
        debugPrint('[BDD] host=auto → autoRunShareFlow');
        _homeKey.currentState?.autoRunShareFlow();
      }
    } catch (e) {
      debugPrint('[BDD] trigger read err: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '漂亮饭',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFF8F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A45),
          surface: const Color(0xFFFFF8F5),
        ),
        useMaterial3: true,
      ),
      home: HomePage(key: _homeKey),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String? _uri;
  String? _base64;
  String _presetId = 'warmwhite';
  Nutrition? _nutrition;
  bool _loading = false;
  String _loadingStage = ''; // why: M3 vision 5-10s 多段反馈（杨总"AI 请求慢"）
  String? _error;
  bool _netReady = false;

  Preset get _preset => kPresets.firstWhere((p) => p.id == _presetId);

  // why: 分享时用 RepaintBoundary 把 preview + CalorieBadge 一起截图进图片（杨总要"图片带卡片信息"）
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // why: app 一打开就 warm network（preheat），用户首次 analyze 时省去 DNS+TLS 冷启动
    _preheatNetwork();
  }

  // why: 真机 BDD 钩子 - devicectl openURL plf://auto 触发全 share flow, 免 UI tap
  // 流程: load sample → preset dazz → analyze → 等 vision → share sheet
  Future<void> autoRunShareFlow() async {
    debugPrint('[BDD] autoRunShareFlow: start');
    await _loadSample();
    debugPrint('[BDD] sample loaded');
    setState(() => _presetId = 'dazz');
    await Future.delayed(const Duration(milliseconds: 300));
    await _analyze();
    debugPrint('[BDD] analyze returned');
    // 多等一会儿 vision 模型返回 + UI 渲染 + share sheet 弹起
    await Future.delayed(const Duration(seconds: 2));
    await _share();
    debugPrint('[BDD] share sheet triggered');
  }

  Future<void> _preheatNetwork() async {
    // why: iPhone 12 通过国内热点上网，minimax 国际域名 DNS 解析不了
    //      但 baidu/taobao 等国内 host 能解析 → 用 baidu 做真实网络预热
    //      minimax host 留给 vision 调用，DNS 失败时也只报 vision 错，不阻塞 share
    try {
      // ignore: unused_local_variable
      final socket = await Socket.connect('www.baidu.com', 443, timeout: const Duration(seconds: 3));
      socket.destroy();
      if (mounted) setState(() => _netReady = true);
    } catch (_) {
      if (mounted) setState(() => _netReady = false);
    }
  }

  Future<void> _pickImage() async => _pickFromSource(ImageSource.gallery);
  Future<void> _takePhoto() async => _pickFromSource(ImageSource.camera);

  Future<void> _pickFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _uri = picked.path;
      _base64 = base64Encode(bytes);
      _nutrition = null;
      _error = null;
    });
  }

  // 测试钩子：bypass 系统 PHPicker（iOS 自动化 picker 进程隔离难驱动）
  // 直接载入内置示例图，供 Maestro BDD flow 用。正式版可移除。
  Future<void> _loadSample() async {
    final bd = await rootBundle.load('assets/ganguoxia.jpg');
    final bytes = bd.buffer.asUint8List();
    final tmp = File('${Directory.systemTemp.path}/pf_sample.jpg');
    await tmp.writeAsBytes(bytes);
    setState(() {
      _uri = tmp.path;
      _base64 = base64Encode(bytes);
      _nutrition = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_base64 == null) return;
    setState(() {
      _loading = true;
      _loadingStage = '识别菜品…';
      _error = null;
      _nutrition = null;
    });
    // 阶段切换：M3 vision 5-10s 多段文案填补空窗（杨总"AI 请求慢"反馈）
    final t1 = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _loadingStage = '计算卡路里…');
    });
    final t2 = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) setState(() => _loadingStage = '生成「不内疚」标签…');
    });
    try {
      final n = await recognizeFood(_base64!);
      setState(() => _nutrition = n);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      t1.cancel();
      t2.cancel();
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingStage = '';
        });
      }
    }
  }

  Future<void> _share() async {
    debugPrint('[BDD] _share() entry _uri=$_uri');
    if (_uri == null) {
      debugPrint('[BDD] _share() abort: _uri null');
      return;
    }
    Uint8List? bytes;
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        debugPrint('[BDD] _share() capture begin');
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) bytes = byteData.buffer.asUint8List();
        image.dispose();
        debugPrint('[BDD] _share() capture done bytes=${bytes?.length}');
      } else {
        debugPrint('[BDD] _share() boundary null');
      }
    } catch (e, st) {
      debugPrint('[BDD] _share() capture FAIL: $e\n$st');
    }
    final n = _nutrition;
    final txt = n != null
        ? '漂亮饭 · ${n.kcal}kcal · ${n.dish}\n'
            '蛋白 ${n.proteinG}g · 碳水 ${n.carbG}g · 脂肪 ${n.fatG}g\n'
            '${n.tags.map((t) => '#$t').join(' ')}\n'
            '💡 不内疚，发出去不心虚'
        : '漂亮饭 · 让一顿饭值得发';
    try {
      String? path;
      if (bytes != null) {
        final tmp = File('${Directory.systemTemp.path}/pf_share.png');
        await tmp.writeAsBytes(bytes);
        path = tmp.path;
      } else {
        path = _uri!;
      }
      debugPrint('[BDD] _share() about to call MethodChannel imagePath=$path');
      final ret = await const MethodChannel('piaoliangfan/share')
          .invokeMethod<String>('share', {'imagePath': path, 'text': txt});
      debugPrint('[BDD] _share() MethodChannel returned: $ret');
    } catch (e, st) {
      debugPrint('[BDD] _share() MethodChannel FAIL: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    // why: iPhone 12 刘海区绘制在 status bar 区域 + 内容上面，top 必须避开
    //      bottom 保持全屏让 home bar 区延伸（杨总"全面屏"诉求 = 不被刘海挡 + 视觉无白条）
    return Scaffold(
      body: SafeArea(
        top: true, // status bar + 刘海让出 47pt
        bottom: false, // home indicator 区域不避（视觉上 100% bottom）
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '漂亮饭',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3D2817),
                  letterSpacing: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  '让一顿漂亮饭，变成值得发的内容',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9B7E6B)),
                ),
              ),
              // why: 网络就绪指示，杨总要"打开就申请网络权限"
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _netReady
                            ? const Color(0xFF7AB97A) // 绿
                            : const Color(0xFFFFB04A), // 橙
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _netReady ? '网络就绪' : '正在连接…',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9B7E6B)),
                    ),
                  ],
                ),
              ),
              // why: 把 preview + CalorieBadge 整块 RepaintBoundary 包起来
              //      _share() 用 _captureKey 找到 RenderRepaintBoundary → toImage
              //      分享出去的图就 = 屏幕上看到的样子（带叠层卡路里标签）
              RepaintBoundary(
                key: _captureKey,
                child: _buildPreview(),
              ),
              if (_uri != null) ...[
                const SizedBox(height: 16),
                _buildPresetRow(),
                const SizedBox(height: 16),
                _buildActions(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '⚠️ $_error',
                  style: const TextStyle(color: Color(0xFFD94A38), fontSize: 13),
                ),
              ],
              if (_nutrition != null) ...[
                const SizedBox(height: 8),
                const Text(
                  '💡 tags 就是你的「不内疚」话术，发出去不心虚',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9B7E6B), fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    const double size = 340;
    if (_uri == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: const Key('selectImage'),
              onTap: _pickImage,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDEEEA), width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🍱', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 8),
                    Text(
                      '选一张你的漂亮饭',
                      style: TextStyle(color: Color(0xFF9B7E6B), fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 拍照按钮：与"选图"并列，调用 ImageSource.camera（需 CAMERA 权限 + iOS NSCameraUsageDescription）
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  key: const Key('takePhoto'),
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18, color: Color(0xFFFF7A45)),
                  label: const Text(
                    '拍照',
                    style: TextStyle(color: Color(0xFFFF7A45), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const Key('bypassSample'),
                  onPressed: _loadSample,
                  child: const Text(
                    '用示例图（测试）',
                    style: TextStyle(color: Color(0xFFFFB04A), fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final preset = _preset;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(_uri!), fit: BoxFit.cover),
              if (preset.overlayOpacity > 0)
                Container(color: preset.overlay.withValues(alpha: preset.overlayOpacity)),
              if (preset.frame == FrameKind.dazz) ...[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 14,
                  // why: 日期戳左下错落 + 轻微右倾 = 拍立得手贴感，破居中规整(D4/A5)
                  child: Transform.rotate(
                    angle: 0.028,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D2817),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'PIAOLIANGFAN · 2026.07.21',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFFF5E6D3),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (_nutrition != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: CalorieBadge(n: _nutrition!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kPresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = kPresets[i];
          final active = p.id == _presetId;
          return GestureDetector(
            key: Key('preset-${p.id}'),
            onTap: () => setState(() => _presetId = p.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFF7A45) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? const Color(0xFFFF7A45) : const Color(0xFFFDEEEA),
                  width: 1.5,
                ),
              ),
              child: Text(
                p.name,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF9B7E6B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const Key('analyzeBtn'),
              onPressed: _loading ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A45),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _loadingStage.isEmpty ? 'AI 思考中…' : _loadingStage,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _nutrition == null ? 'AI 算这顿值不值得' : '重新算这顿',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // why: Flutter OutlinedButton 在 iOS 26 + XCUITest a11y click 下 onPressed 不触发
        //      用 Semantics(onTap: ...) 强制 iOS 暴露 onTap 动作 → XCUITest click 走 Semantics.onTap
        Semantics(
          button: true,
          onTap: _share,
          label: '分享',
          child: OutlinedButton(
            key: const Key('shareBtn'),
            onPressed: _share,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF7A45),
              side: const BorderSide(color: Color(0xFFFF7A45), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            ),
            child: const Text(
              '分享',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
