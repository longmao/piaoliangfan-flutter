// 美化预设（参考 design-refs.md 视觉调性：暖白+番茄橙+胶片框）
// demo 用色层叠加模拟滤镜（V2 可接 image 库做真处理 / 九宫格）
import 'package:flutter/material.dart';

enum FrameKind { none, dazz }

class Preset {
  final String id;
  final String name;
  final Color overlay;
  final double overlayOpacity;
  final FrameKind frame;

  const Preset({
    required this.id,
    required this.name,
    required this.overlay,
    required this.overlayOpacity,
    this.frame = FrameKind.none,
  });
}

const List<Preset> kPresets = [
  Preset(id: 'clean', name: '原片', overlay: Color(0x00000000), overlayOpacity: 0),
  Preset(id: 'warmwhite', name: '暖白', overlay: Color(0xFFFFF1E6), overlayOpacity: 0.18),
  Preset(id: 'tomato', name: '番茄橙', overlay: Color(0xFFFF7A45), overlayOpacity: 0.12),
  Preset(
    id: 'dazz',
    name: '胶片框',
    overlay: Color(0xFFFFE8C2),
    overlayOpacity: 0.15,
    frame: FrameKind.dazz,
  ),
];
