import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'skins.dart';
import 'store.dart';

class PadScreen extends StatefulWidget {
  const PadScreen({super.key});

  @override
  State<PadScreen> createState() => _PadScreenState();
}

class _PadScreenState extends State<PadScreen> {
  final Store st = Store.i;
  final Engine eng = Engine.i;
  final ValueNotifier<String> lcd = ValueNotifier<String>('PAD --\nSiap main');
  bool busy = false;

  Skin get skin => st.skins.firstWhere((s) => s.id == st.skinId,
      orElse: () => st.skins.first);

  String _label(int i) {
    final p = st.pads[i];
    return p.isEmpty ? '-' : prettyName(p);
  }

  void _hit(int i) {
    eng.hit(i);
    final p = st.pads[i];
    lcd.value =
        'PAD ${(i + 1).toString().padLeft(2, '0')}  ${p.isEmpty ? '(kosong)' : prettyName(p)}\nZIP: ${p.isEmpty ? '-' : groupOf(p)}';
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<String?> _pickPath(String ext) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r == null || r.files.isEmpty) return null;
    final p = r.files.first.path;
    if (p == null) return null;
    if (ext == 'audio') {
      if (!isAudioName(p)) {
        _toast('Pilih file wav / mp3 / ogg / m4a');
        return null;
      }
    } else if (!p.toLowerCase().endsWith('.$ext')) {
      _toast('Pilih file .$ext');
      return null;
    }
    return p;
  }

  Future<void> _importZip() async {
    final path = await _pickPath('zip');
    if (path == null) return;
    setState(() => busy = true);
    try {
      final files = await st.importZip(path);
      if (files.isEmpty) {
        _toast('Zip tidak berisi wav/mp3');
      } else {
        for (var k = 0; k < 12 && k < files.length; k++) {
          st.pads[k] = files[k];
        }
        await st.save();
        await eng.loadAll(st.pads);
        _toast('${files.length} sample masuk. Tahan pad untuk mapping sendiri.');
      }
    } catch (e) {
      _toast('Gagal import zip: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _importSkin() async {
    final path = await _pickPath('json');
    if (path == null) return;
    try {
      final s = await st.importSkin(path);
      if (s == null) {
        _toast('File skin tidak valid');
      } else {
        st.skinId = s.id;
        await st.save();
        if (mounted) setState(() {});
        _toast('Skin "${s.name}" dipakai');
      }
    } catch (e) {
      _toast('Gagal import skin: $e');
    }
  }

  Future<void> _assign(int pad) async {
    final lib = await st.library();
    if (!mounted) return;
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Sample untuk PAD ${pad + 1}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Ambil file audio dari HP...'),
              onTap: () => Navigator.pop(ctx, '__pick__'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_off),
              title: const Text('Kosongkan pad'),
              onTap: () => Navigator.pop(ctx, '__empty__'),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: lib.length,
                itemBuilder: (c, k) => ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(lib[k].name),
                  subtitle: Text(lib[k].group),
                  selected: st.pads[pad] == lib[k].path,
                  onTap: () => Navigator.pop(c, lib[k].path),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (res == null) return;
    try {
      String path = res;
      if (res == '__pick__') {
        final p = await _pickPath('audio');
        if (p == null) return;
        path = await st.importAudio(p);
      } else if (res == '__empty__') {
        path = '';
      }
      st.pads[pad] = path;
      await st.save();
      await eng.load(pad, path);
      if (mounted) setState(() {});
    } catch (e) {
      _toast('Gagal: $e');
    }
  }

  Future<void> _skinSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final s in st.skins)
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: s.glow,
                  child: CircleAvatar(radius: 10, backgroundColor: s.pad)),
              title: Text(s.name),
              trailing: s.id == st.skinId ? const Icon(Icons.check) : null,
              onTap: () async {
                st.skinId = s.id;
                await st.save();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
    );
  }

  Future<void> _menu() async {
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_zip),
            title: const Text('Import zip sample'),
            onTap: () => Navigator.pop(ctx, 'zip'),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Pilih skin'),
            onTap: () => Navigator.pop(ctx, 'skin'),
          ),
          ListTile(
            leading: const Icon(Icons.brush),
            title: const Text('Import skin (.json)'),
            onTap: () => Navigator.pop(ctx, 'skinjson'),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Kembalikan sample bawaan'),
            onTap: () => Navigator.pop(ctx, 'reset'),
          ),
        ],
      ),
    );
    switch (act) {
      case 'zip':
        await _importZip();
        break;
      case 'skin':
        await _skinSheet();
        break;
      case 'skinjson':
        await _importSkin();
        break;
      case 'reset':
        setState(() => busy = true);
        try {
          await st.resetToDefaults();
          await eng.loadAll(st.pads);
          _toast('Sample bawaan dipulihkan');
        } catch (e) {
          _toast('Gagal: $e');
        }
        if (mounted) setState(() => busy = false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = skin;
    return Scaffold(
      backgroundColor: s.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
              child: Row(
                children: [
                  Text('DTX KENDANG',
                      style: TextStyle(
                          color: s.text,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          fontSize: 16)),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.palette, color: s.text),
                      onPressed: _skinSheet),
                  IconButton(
                      icon: Icon(Icons.menu, color: s.text), onPressed: _menu),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: LayoutBuilder(builder: (ctx, cs) {
                  final landscape = cs.maxWidth > cs.maxHeight;
                  final cols = landscape ? 4 : 3;
                  final rows = 12 ~/ cols;
                  const gap = 10.0;
                  return Column(
                    children: [
                      for (var r = 0; r < rows; r++) ...[
                        if (r > 0) const SizedBox(height: gap),
                        Expanded(
                          child: Row(
                            children: [
                              for (var c = 0; c < cols; c++) ...[
                                if (c > 0) const SizedBox(width: gap),
                                Expanded(
                                  child: PadWidget(
                                    index: r * cols + c,
                                    skin: s,
                                    label: _label(r * cols + c),
                                    onHit: () => _hit(r * cols + c),
                                    onLong: () => _assign(r * cols + c),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1A10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F4D2B), width: 2),
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: lcd,
                builder: (c, v, w) => Text(
                  v,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF69F0AE),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PadWidget extends StatefulWidget {
  final int index;
  final Skin skin;
  final String label;
  final VoidCallback onHit;
  final VoidCallback onLong;

  const PadWidget({
    super.key,
    required this.index,
    required this.skin,
    required this.label,
    required this.onHit,
    required this.onLong,
  });

  @override
  State<PadWidget> createState() => _PadWidgetState();
}

class _PadWidgetState extends State<PadWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280), value: 1.0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.skin;
    return Listener(
      onPointerDown: (_) {
        widget.onHit(); // suara dulu, tanpa menunggu gesture
        _c.forward(from: 0.0);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: widget.onLong,
        child: AnimatedBuilder(
          animation: _c,
          builder: (ctx, child) {
            final f = 1.0 - _c.value;
            return Container(
              decoration: BoxDecoration(
                color: Color.lerp(s.pad, s.glow, f * 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Color.lerp(s.border, s.glow, f)!, width: 2 + f * 1.5),
                boxShadow: [
                  BoxShadow(
                    color: alpha(s.glow, 0.15 + 0.6 * f),
                    blurRadius: 8 + 22 * f,
                    spreadRadius: f * 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (s.carbon)
                      const RepaintBoundary(
                        child: CustomPaint(painter: CarbonPainter()),
                      ),
                    if (s.carbon && f > 0.01)
                      Container(color: alpha(s.glow, f * 0.35)),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${widget.index + 1}',
                              style: TextStyle(
                                  color: s.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: alpha(s.text, 0.7), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CarbonPainter extends CustomPainter {
  const CarbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 6.0;
    final a = Paint()..color = const Color(0xFF1E1E1E);
    final b = Paint()..color = const Color(0xFF101010);
    final hi = Paint()..color = const Color(0x22FFFFFF);
    var yi = 0;
    for (double y = 0; y < size.height; y += cell) {
      var xi = 0;
      for (double x = 0; x < size.width; x += cell) {
        final even = (xi + yi) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), even ? a : b);
        if (even) canvas.drawRect(Rect.fromLTWH(x, y, cell, 1.2), hi);
        xi++;
      }
      yi++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
