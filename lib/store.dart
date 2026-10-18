import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'samples.dart';
import 'skins.dart';

class Sample {
  final String name, path, group;
  Sample(this.name, this.path, this.group);
}

bool isAudioName(String n) {
  final l = n.toLowerCase();
  return l.endsWith('.wav') ||
      l.endsWith('.mp3') ||
      l.endsWith('.ogg') ||
      l.endsWith('.m4a');
}

String prettyName(String path) {
  var b = path.split('/').last;
  final dot = b.lastIndexOf('.');
  if (dot > 0) b = b.substring(0, dot);
  b = b.replaceFirst(RegExp(r'^\d+[_\- ]+'), '').replaceAll('_', ' ');
  return b.isEmpty ? 'Sample' : b;
}

String groupOf(String path) {
  final parts = path.split('/');
  if (parts.length < 2) return '-';
  final g = parts[parts.length - 2];
  return g == 'default_samples' ? 'Bawaan' : g;
}

/// Penyimpanan pengaturan ke file JSON sendiri (tanpa shared_preferences).
class Store {
  Store._();
  static final Store i = Store._();

  Directory root = Directory.systemTemp;
  List<String> pads = List<String>.filled(12, '');
  List<String> defaultPaths = [];
  String skinId = 'neon';
  List<Skin> skins = List<Skin>.of(builtInSkins);

  Future<void> init() async {
    try {
      root = await getApplicationDocumentsDirectory();
    } catch (_) {}
    try {
      final f = File('${root.path}/settings.json');
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString());
        if (j is Map) {
          skinId = (j['skin'] ?? 'neon').toString();
          final p = j['pads'];
          if (p is List) {
            for (var k = 0; k < 12 && k < p.length; k++) {
              pads[k] = p[k].toString();
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      await File('${root.path}/settings.json')
          .writeAsString(jsonEncode({'skin': skinId, 'pads': pads}));
    } catch (_) {}
  }

  Future<void> loadSkins() async {
    final list = List<Skin>.of(builtInSkins);
    try {
      final d = Directory('${root.path}/skins');
      if (await d.exists()) {
        await for (final e in d.list()) {
          if (e is File && e.path.toLowerCase().endsWith('.json')) {
            try {
              final j = jsonDecode(await e.readAsString());
              if (j is Map) {
                final id = 'u_${e.path.split('/').last}';
                list.add(Skin.fromJson(j, id));
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    skins = list;
  }

  Future<Skin?> importSkin(String path) async {
    final txt = await File(path).readAsString();
    final j = jsonDecode(txt);
    if (j is! Map) return null;
    final d = Directory('${root.path}/skins');
    if (!await d.exists()) await d.create(recursive: true);
    final fname = path.split('/').last;
    final dest = '${d.path}/$fname';
    await File(dest).writeAsString(txt);
    final skin = Skin.fromJson(j, 'u_$fname');
    skins.removeWhere((s) => s.id == skin.id);
    skins.add(skin);
    return skin;
  }

  Future<void> ensureDefaults() async {
    defaultPaths = await buildDefaultSamples(root.path);
  }

  /// Pad kosong / file hilang -> isi dengan sample bawaan.
  Future<void> mapMissing() async {
    for (var k = 0; k < 12; k++) {
      final p = pads[k];
      if (p.isEmpty || !File(p).existsSync()) {
        pads[k] = k < defaultPaths.length ? defaultPaths[k] : '';
      }
    }
    await save();
  }

  Future<void> resetToDefaults() async {
    await ensureDefaults();
    for (var k = 0; k < 12; k++) {
      pads[k] = defaultPaths[k];
    }
    await save();
  }

  Future<List<Sample>> library() async {
    final out = <Sample>[];
    for (final dir in [
      Directory('${root.path}/default_samples'),
      Directory('${root.path}/samples'),
    ]) {
      if (!await dir.exists()) continue;
      final files = <String>[];
      await for (final e in dir.list(recursive: true)) {
        if (e is File && isAudioName(e.path)) files.add(e.path);
      }
      files.sort();
      for (final p in files) {
        out.add(Sample(prettyName(p), p, groupOf(p)));
      }
    }
    return out;
  }

  Future<List<String>> importZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final arc = ZipDecoder().decodeBytes(bytes);
    var name = zipPath.split('/').last;
    name = name.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');
    final dir = Directory('${root.path}/samples/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
    final out = <String>[];
    for (final f in arc) {
      if (!f.isFile) continue;
      final base = f.name.split('/').last;
      if (base.startsWith('.') || !isAudioName(base)) continue;
      final file = File('${dir.path}/$base');
      await file.writeAsBytes(List<int>.from(f.content as List<int>));
      out.add(file.path);
    }
    out.sort();
    return out;
  }

  Future<String> importAudio(String path) async {
    final dir = Directory('${root.path}/samples/Lainnya');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dest = '${dir.path}/${path.split('/').last}';
    await File(path).copy(dest);
    return dest;
  }
}
