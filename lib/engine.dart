import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

/// Mesin suara: tiap pad punya 2 player low-latency (bergantian) agar
/// pukulan cepat tidak saling memotong dan tidak ada delay.
class Engine {
  Engine._();
  static final Engine i = Engine._();

  static const int perPad = 2;
  final List<List<AudioPlayer>> _pools =
      List.generate(12, (_) => <AudioPlayer>[]);
  final List<int> _idx = List<int>.filled(12, 0);

  Future<void> load(int pad, String path) async {
    final old = _pools[pad];
    _pools[pad] = <AudioPlayer>[];
    for (final p in old) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    if (path.isEmpty || !File(path).existsSync()) return;
    final fresh = <AudioPlayer>[];
    for (var k = 0; k < perPad; k++) {
      final p = AudioPlayer();
      try {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(DeviceFileSource(path));
        fresh.add(p);
      } catch (_) {
        try {
          await p.dispose();
        } catch (_) {}
      }
    }
    _pools[pad] = fresh;
  }

  Future<void> loadAll(List<String> paths) async {
    await Future.wait(
      List.generate(12, (k) async {
        try {
          await load(k, paths[k]);
        } catch (_) {}
      }),
    );
  }

  void hit(int pad) {
    final pool = _pools[pad];
    if (pool.isEmpty) return;
    final p = pool[_idx[pad] % pool.length];
    _idx[pad]++;
    _fire(p);
  }

  Future<void> _fire(AudioPlayer p) async {
    try {
      await p.stop();
      await p.resume();
    } catch (_) {}
  }
}
