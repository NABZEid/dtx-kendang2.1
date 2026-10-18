import 'package:flutter/material.dart';

Color alpha(Color c, double o) =>
    c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

Color _hex(dynamic v, Color fb) {
  try {
    var h = v.toString().replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return fb;
  }
}

class Skin {
  final String id;
  final String name;
  final Color bg, pad, border, glow, text;
  final bool carbon;

  const Skin({
    required this.id,
    required this.name,
    required this.bg,
    required this.pad,
    required this.border,
    required this.glow,
    required this.text,
    this.carbon = false,
  });

  factory Skin.fromJson(Map<dynamic, dynamic> j, String id) {
    return Skin(
      id: id,
      name: (j['name'] ?? id).toString(),
      bg: _hex(j['bg'], const Color(0xFF05060A)),
      pad: _hex(j['pad'], const Color(0xFF12141F)),
      border: _hex(j['border'], const Color(0xFF00E5FF)),
      glow: _hex(j['glow'], const Color(0xFFE040FB)),
      text: _hex(j['text'], Colors.white),
      carbon: j['carbon'] == true,
    );
  }
}

const List<Skin> builtInSkins = [
  Skin(
    id: 'neon',
    name: 'Neon',
    bg: Color(0xFF05060A),
    pad: Color(0xFF12141F),
    border: Color(0xFF00E5FF),
    glow: Color(0xFFE040FB),
    text: Colors.white,
  ),
  Skin(
    id: 'karbon',
    name: 'Karbon',
    bg: Color(0xFF0A0A0A),
    pad: Color(0xFF1A1A1A),
    border: Color(0xFF444444),
    glow: Color(0xFFFF6D00),
    text: Color(0xFFE0E0E0),
    carbon: true,
  ),
  Skin(
    id: 'putih',
    name: 'Putih',
    bg: Color(0xFFF2F4F8),
    pad: Color(0xFFFFFFFF),
    border: Color(0xFFB0B8C8),
    glow: Color(0xFF2979FF),
    text: Color(0xFF22262E),
  ),
];
