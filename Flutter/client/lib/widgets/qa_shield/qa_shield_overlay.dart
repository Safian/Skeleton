import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/bug_report_repository.dart';
import '../../services/log_buffer.dart';

// ============================================================
// QaShieldOverlay  [M4.1]
//
// Wrapper widget – csak kDebugMode-ban aktív.
// Aktiválás: 3 ujjas, 3-szoros egymás utáni koppintás 1 másodpercen belül.
//
// Használat:
//   MaterialApp(
//     home: QaShieldOverlay(child: AppRoot()),
//   )
// ============================================================

class QaShieldOverlay extends StatefulWidget {
  final Widget child;
  const QaShieldOverlay({super.key, required this.child});

  @override
  State<QaShieldOverlay> createState() => _QaShieldOverlayState();
}

class _QaShieldOverlayState extends State<QaShieldOverlay> {
  final GlobalKey _repaintKey = GlobalKey();

  // Tap detektor – 3 ujjas 3x-os koppintás
  final Set<int> _activePointers = {};
  bool _threeFingersRegistered = false;
  int _tapCount = 0;
  DateTime? _lastTap;
  static const _requiredTaps = 3;
  static const _requiredFingers = 3;
  static const _window = Duration(seconds: 2);

  void _onPointerDown(PointerDownEvent event) {
    if (!kDebugMode) return;
    _activePointers.add(event.pointer);

    // Csak akkor számolunk, ha egyszerre pontosan _requiredFingers ujj van lent
    if (_activePointers.length == _requiredFingers && !_threeFingersRegistered) {
      _threeFingersRegistered = true;
      final now = DateTime.now();
      if (_lastTap == null || now.difference(_lastTap!) > _window) {
        _tapCount = 0;
      }
      _lastTap = now;
      _tapCount++;
      if (_tapCount >= _requiredTaps) {
        _tapCount = 0;
        _trigger();
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _threeFingersRegistered = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _threeFingersRegistered = false;
  }

  Future<void> _trigger() async {
    // Screenshot
    Uint8List? screenshotPng;
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final img = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        screenshotPng = byteData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[QaShield] screenshot error: $e');
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BugReportSheet(screenshotPng: screenshotPng),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
          children: [
            widget.child,
            // QA Shield badge (bal alsó sarok)
            Positioned(
              left: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                  ),
                  child: const Text(
                    'QA',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
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

// ============================================================
// _BugReportSheet – bottom sheet annotáció + form
// ============================================================

class _BugReportSheet extends StatefulWidget {
  final Uint8List? screenshotPng;
  const _BugReportSheet({this.screenshotPng});

  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Form
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  String _priority       = 'medium';
  bool _isSending        = false;
  bool _sent             = false;

  // Annotáció
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  Color _penColor = Colors.red;
  double _penWidth = 3.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A cím kötelező!')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Eszközadatok összegyűjtése
      final deviceInfo = await _collectDeviceInfo();
      final routeName  = ModalRoute.of(context)?.settings.name ?? 'unknown';
      final logs       = LogBuffer.instance.recent();

      // Annotált screenshot előállítása (ha van)
      Uint8List? finalScreenshot = widget.screenshotPng;
      if (widget.screenshotPng != null && _strokes.isNotEmpty) {
        finalScreenshot = await _renderAnnotatedScreenshot();
      }

      await BugReportRepository.instance.submit(
        title:         _titleCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        priority:      _priority,
        routeName:     routeName,
        logs:          logs,
        deviceInfo:    deviceInfo,
        screenshotPng: finalScreenshot,
      );

      if (mounted) setState(() { _isSending = false; _sent = true; });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Map<String, String>> _collectDeviceInfo() async {
    final pkg    = await PackageInfo.fromPlatform();
    final result = <String, String>{
      'app_version': pkg.version,
      'app_build':   pkg.buildNumber,
    };
    try {
      final di = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await di.webBrowserInfo;
        result['platform'] = 'Web';
        result['browser']  = w.browserName.name;
      } else if (Platform.isAndroid) {
        final a = await di.androidInfo;
        result['platform'] = 'Android ${a.version.release}';
        result['device']   = '${a.brand} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await di.iosInfo;
        result['platform'] = 'iOS ${i.systemVersion}';
        result['device']   = i.utsname.machine;
      }
    } catch (_) {}

    // Supabase user ID
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) result['user_id'] = uid;

    return result;
  }

  Future<Uint8List?> _renderAnnotatedScreenshot() async {
    if (widget.screenshotPng == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(widget.screenshotPng!);
      final frame = await codec.getNextFrame();
      final baseImg = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Base image
      canvas.drawImage(baseImg, Offset.zero, Paint());

      // Strokes
      for (final stroke in _strokes) {
        final paint = Paint()
          ..color       = stroke.color
          ..strokeWidth = stroke.width
          ..strokeCap   = StrokeCap.round
          ..strokeJoin  = StrokeJoin.round
          ..style       = PaintingStyle.stroke;
        if (stroke.points.length == 1) {
          canvas.drawCircle(stroke.points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
        } else {
          final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
          for (final pt in stroke.points.skip(1)) {
            path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, paint);
        }
      }

      final picture = recorder.endRecording();
      final img     = await picture.toImage(baseImg.width, baseImg.height);
      final data    = await img.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[QaShield] annotate error: $e');
      return widget.screenshotPng;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'QA Bug Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.orange,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Részletek'),
                Tab(text: 'Annotáció'),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFormTab(controller),
                    _buildAnnotationTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTab(ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(16),
      children: [
        // Cím
        TextField(
          controller: _titleCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Cím *',
            labelStyle: TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Color(0xFF252540),
          ),
        ),
        const SizedBox(height: 12),
        // Leírás
        TextField(
          controller: _descCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Leírás',
            labelStyle: TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Color(0xFF252540),
          ),
        ),
        const SizedBox(height: 12),
        // Prioritás
        DropdownButtonFormField<String>(
          initialValue: _priority,
          dropdownColor: const Color(0xFF252540),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Prioritás',
            labelStyle: TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Color(0xFF252540),
          ),
          items: const [
            DropdownMenuItem(value: 'low',      child: Text('🟢 Alacsony')),
            DropdownMenuItem(value: 'medium',   child: Text('🟡 Közepes')),
            DropdownMenuItem(value: 'high',     child: Text('🔴 Magas')),
            DropdownMenuItem(value: 'critical', child: Text('💥 Kritikus')),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 'medium'),
        ),
        const SizedBox(height: 12),
        // Logok preview
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Utolsó ${LogBuffer.instance.length} log:',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                LogBuffer.instance.recent(10).reversed.join('\n'),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Küldés gomb
        ElevatedButton(
          onPressed: _isSending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ),
                )
              : _sent
                  ? const Icon(Icons.check, color: Colors.white)
                  : const Text('Beküldés', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAnnotationTab() {
    if (widget.screenshotPng == null) {
      return const Center(
        child: Text(
          'Nincs screenshot',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return Column(
      children: [
        // Tollszín + vastagság
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('Szín:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              for (final c in [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.white])
                GestureDetector(
                  onTap: () => setState(() => _penColor = c),
                  child: Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _penColor == c ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white54, size: 20),
                onPressed: _strokes.isEmpty
                    ? null
                    : () => setState(() => _strokes.removeLast()),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                onPressed: _strokes.isEmpty
                    ? null
                    : () => setState(() => _strokes.clear()),
              ),
            ],
          ),
        ),
        // Canvas
        Expanded(
          child: GestureDetector(
            onPanStart: (d) {
              setState(() {
                _currentStroke = _Stroke(
                  color: _penColor,
                  width: _penWidth,
                  points: [d.localPosition],
                );
              });
            },
            onPanUpdate: (d) {
              if (_currentStroke == null) return;
              setState(() {
                _currentStroke = _Stroke(
                  color: _currentStroke!.color,
                  width: _currentStroke!.width,
                  points: [..._currentStroke!.points, d.localPosition],
                );
              });
            },
            onPanEnd: (_) {
              if (_currentStroke != null) {
                setState(() {
                  _strokes.add(_currentStroke!);
                  _currentStroke = null;
                });
              }
            },
            child: CustomPaint(
              painter: _AnnotationPainter(
                imageBytes: widget.screenshotPng!,
                strokes: _strokes,
                currentStroke: _currentStroke,
              ),
              child: Container(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Rajz adatmodel ───────────────────────────────────────────

class _Stroke {
  final Color color;
  final double width;
  final List<Offset> points;
  const _Stroke({required this.color, required this.width, required this.points});
}

// ── CustomPainter ────────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  final Uint8List imageBytes;
  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  ui.Image? _cachedImage;

  _AnnotationPainter({
    required this.imageBytes,
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // A kép betöltés async, ezért ha még nincs cache, indítjuk a betöltést
    if (_cachedImage == null) {
      _loadImage();
      // Fehér háttér placeholder
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white12,
      );
    } else {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: _cachedImage!,
        fit: BoxFit.contain,
      );
    }

    // Strokes
    void drawStroke(_Stroke stroke) {
      final paint = Paint()
        ..color       = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
        ..style       = PaintingStyle.stroke;
      if (stroke.points.isEmpty) return;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final pt in stroke.points.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    for (final s in strokes) { drawStroke(s); }
    if (currentStroke != null) drawStroke(currentStroke!);
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    _cachedImage = frame.image;
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}
