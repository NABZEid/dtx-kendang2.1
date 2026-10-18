import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// 12 sample bawaan (sintetis, dibuat lewat kode). Urutan = pad 1..12.
const List<String> kDefaultSampleNames = [
  'Dung', 'Tak', 'Tung', 'Pak', 'Ketipung', 'Kick',
  'Snare', 'HiHat_Closed', 'HiHat_Open', 'Tom', 'Crash', 'Ride',
];

const int _sr = 44100;

Uint8List _wav(Float64List s) {
  final n = s.length;
  final b = ByteData(44 + n * 2);
  void str(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, _sr, Endian.little);
  b.setUint32(28, _sr * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final double v = s[i] > 1.0 ? 1.0 : (s[i] < -1.0 ? -1.0 : s[i]);
    b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

Float64List _tone(double dur, double f0, double f1, double decay,
    {double noise = 0.0, int seed = 1}) {
  final rnd = Random(seed);
  final n = (dur * _sr).toInt();
  final out = Float64List(n);
  double ph = 0.0;
  for (var i = 0; i < n; i++) {
    final double t = i / _sr;
    final double f = f1 + (f0 - f1) * exp(-t * 30);
    ph += 2 * pi * f / _sr;
    final double env = exp(-t * decay);
    final double att = i < 40 ? i / 40.0 : 1.0;
    out[i] = (sin(ph) * (1 - noise) + (rnd.nextDouble() * 2 - 1) * noise) *
        env *
        att *
        0.9;
  }
  return out;
}

Float64List _hiss(double dur, double decay,
    {int seed = 2, double gain = 0.7}) {
  final rnd = Random(seed);
  final n = (dur * _sr).toInt();
  final out = Float64List(n);
  double prev = 0.0;
  for (var i = 0; i < n; i++) {
    final double x = rnd.nextDouble() * 2 - 1;
    final double hp = x - prev;
    prev = x;
    final double att = i < 20 ? i / 20.0 : 1.0;
    out[i] = hp * 0.5 * exp(-i / _sr * decay) * att * gain;
  }
  return out;
}

Float64List _mix(Float64List a, Float64List b) {
  final n = max(a.length, b.length);
  final o = Float64List(n);
  for (var i = 0; i < n; i++) {
    final double x = i < a.length ? a[i] : 0.0;
    final double y = i < b.length ? b[i] : 0.0;
    o[i] = x + y;
  }
  return o;
}

Float64List _ride() {
  final n = (1.0 * _sr).toInt();
  final o = Float64List(n);
  const fr = [3150.0, 4380.0, 5230.0, 6870.0];
  for (var i = 0; i < n; i++) {
    final double t = i / _sr;
    double v = 0.0;
    for (final f in fr) {
      v += sin(2 * pi * f * t);
    }
    final double att = i < 20 ? i / 20.0 : 1.0;
    o[i] = v * 0.18 * exp(-t * 5) * att;
  }
  return _mix(o, _hiss(1.0, 8.0, seed: 9, gain: 0.25));
}

List<Float64List> _synthAll() => [
      _tone(0.45, 160.0, 95.0, 7.0),
      _mix(_tone(0.12, 900.0, 700.0, 40.0, noise: 0.25),
          _hiss(0.08, 60.0, gain: 0.4)),
      _tone(0.30, 240.0, 170.0, 11.0),
      _mix(_tone(0.10, 620.0, 520.0, 45.0, noise: 0.3),
          _hiss(0.06, 70.0, gain: 0.35)),
      _tone(0.22, 300.0, 220.0, 16.0),
      _tone(0.40, 150.0, 48.0, 9.0),
      _mix(_tone(0.25, 200.0, 180.0, 18.0, noise: 0.1),
          _hiss(0.25, 16.0, seed: 5)),
      _hiss(0.07, 70.0, seed: 3),
      _hiss(0.45, 9.0, seed: 4),
      _tone(0.40, 200.0, 110.0, 8.0),
      _hiss(1.3, 3.5, seed: 6, gain: 0.8),
      _ride(),
    ];

/// Buat file WAV bawaan (sekali saja), kembalikan 12 path.
Future<List<String>> buildDefaultSamples(String rootPath) async {
  final dir = Directory('$rootPath/default_samples');
  if (!await dir.exists()) await dir.create(recursive: true);
  final paths = <String>[];
  List<Float64List>? data;
  for (var i = 0; i < 12; i++) {
    final f = File(
        '${dir.path}/${(i + 1).toString().padLeft(2, '0')}_${kDefaultSampleNames[i]}.wav');
    if (!await f.exists()) {
      data ??= _synthAll();
      await f.writeAsBytes(_wav(data[i]), flush: true);
    }
    paths.add(f.path);
  }
  return paths;
}
