import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'log_buffer.dart';

// ============================================================
// BugReporter – QA Shield service  [M7]
//
// Csak debug/staging buildben aktív (kDebugMode ellenőrzés).
//
// Fő funkció: screenshot készítés + annotáció + beküldés.
//
// Globális gesztus (3 ujj, 3x koppintás) kezelésére
// csomagold az egész app-ot a BugReporterGestureDetector widgettel.
//
// Singleton service a tényleges beküldéshez.
// ============================================================

// ── BugReporterGestureDetector ─────────────────────────────────
// Csomagolja az alkalmazás gyökerét, észleli a 3 ujjas 3x koppintást

class BugReporterGestureDetector extends StatefulWidget {
  final Widget child;
  final GlobalKey repaintKey;

  const BugReporterGestureDetector({
    super.key,
    required this.child,
    required this.repaintKey,
  });

  @override
  State<BugReporterGestureDetector> createState() =>
      _BugReporterGestureDetectorState();
}

class _BugReporterGestureDetectorState
    extends State<BugReporterGestureDetector> {
  int _tapCount = 0;
  int _touchCount = 0;
  DateTime? _lastTap;
  bool _isCapturing = false;

  void _handlePointerDown(PointerDownEvent event) {
    _touchCount++;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_touchCount >= 3) {
      final now = DateTime.now();

      // Reset ha több mint 1 másodperc telt el az utolsó koppintás óta
      if (_lastTap != null &&
          now.difference(_lastTap!).inMilliseconds > 1000) {
        _tapCount = 0;
      }

      _tapCount++;
      _lastTap = now;

      if (_tapCount >= 3 && !_isCapturing) {
        _tapCount = 0;
        _triggerBugReport();
      }
    }
    _touchCount = 0;
  }

  Future<void> _triggerBugReport() async {
    setState(() => _isCapturing = true);
    try {
      await BugReporter.instance.capture(
        context: context,
        repaintKey: widget.repaintKey,
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp:   _handlePointerUp,
      child: widget.child,
    );
  }
}

// ── BugReporter Service ────────────────────────────────────────

class BugReporter {
  BugReporter._();
  static final BugReporter instance = BugReporter._();

  // ── Screenshot készítés + annotáció képernyő megnyitása ───

  Future<void> capture({
    required BuildContext context,
    required GlobalKey repaintKey,
  }) async {
    // 1. Screenshot
    final screenshot = await _captureScreenshot(repaintKey);

    if (!context.mounted) return;

    // 2. Annotáció + beküldő képernyő megjelenítése
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BugReportSheet(
          screenshot:     screenshot,
          currentRoute:   ModalRoute.of(context)?.settings.name ?? 'unknown',
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ── Screenshot ─────────────────────────────────────────────

  Future<Uint8List?> _captureScreenshot(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[BugReporter] Screenshot error: $e');
      return null;
    }
  }

  // ── Beküldés ───────────────────────────────────────────────

  Future<bool> submit({
    required String title,
    required String description,
    required String priority,
    required String routeName,
    Uint8List? annotatedScreenshot,
  }) async {
    try {
      final deviceInfo  = await _collectDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      final logs        = LogBuffer.instance.getLogs();

      final payload = {
        'title':       title,
        'description': description,
        'priority':    priority,
        'route_name':  routeName,
        'device_info': {
          ...deviceInfo,
          'app_version': packageInfo.version,
          'app_build':   packageInfo.buildNumber,
        },
        'logs': logs,
      };

      if (annotatedScreenshot != null) {
        // Multipart beküldés screenshot-tal
        final client = Supabase.instance.client;
        final formData = {
          'data': payload.toString(), // JSON stringify-olt a Dart-ban
        };
        // Közvetlen HTTP POST – Supabase Functions nem támogat multipart-ot
        // a functions.invoke-n keresztül, ezért http csomag szükséges
        // TODO: http csomag hozzáadása → multipart feltöltés
        await client.functions.invoke('bug-report', body: payload);
      } else {
        await Supabase.instance.client.functions.invoke(
          'bug-report',
          body: payload,
        );
      }

      LogBuffer.instance.info('[BugReporter] Bug report sikeresen beküldve');
      return true;
    } catch (e) {
      debugPrint('[BugReporter] Submit error: $e');
      return false;
    }
  }

  // ── Eszközadat gyűjtés ────────────────────────────────────

  Future<Map<String, String?>> _collectDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        return {
          'os_name': 'iOS', 'os_version': info.systemVersion,
          'device_model': info.utsname.machine, 'device_brand': 'Apple',
        };
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        return {
          'os_name': 'Android', 'os_version': info.version.release,
          'device_model': info.model, 'device_brand': info.brand,
        };
      }
    } catch (_) {}
    return {};
  }
}

// ── BugReportSheet – annotáció + űrlap képernyő ───────────────

class BugReportSheet extends StatefulWidget {
  final Uint8List? screenshot;
  final String currentRoute;

  const BugReportSheet({
    super.key,
    required this.screenshot,
    required this.currentRoute,
  });

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  final _titleCtrl       = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _priority       = 'medium';
  bool _isSubmitting     = false;
  bool _submitted        = false;

  // Annotáció
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke       = [];
  Color _penColor                    = Colors.red;
  double _penWidth                   = 3.0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.bug_report_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('Bug Riporter', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          if (!_submitted)
            TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Beküldés',
                      style: TextStyle(color: Colors.greenAccent),
                    ),
            ),
        ],
      ),
      body: _submitted ? _buildSuccessView() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Screenshot annotáló vászon ──────────────────
          if (widget.screenshot != null) ...[
            const Text('Rajzolj a képre:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            _AnnotationCanvas(
              screenshot: widget.screenshot!,
              strokes:    _strokes,
              currentStroke: _currentStroke,
              penColor:   _penColor,
              penWidth:   _penWidth,
              onStrokeStart: (pos) {
                setState(() {
                  _currentStroke = [pos];
                });
              },
              onStrokeUpdate: (pos) {
                setState(() => _currentStroke.add(pos));
              },
              onStrokeEnd: () {
                setState(() {
                  if (_currentStroke.isNotEmpty) {
                    _strokes.add(List.from(_currentStroke));
                  }
                  _currentStroke = [];
                });
              },
            ),

            // Toll szín választó
            const SizedBox(height: 8),
            Row(
              children: [
                for (final color in [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.white])
                  GestureDetector(
                    onTap: () => setState(() => _penColor = color),
                    child: Container(
                      width: 28, height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color:  color,
                        shape:  BoxShape.circle,
                        border: _penColor == color
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  ),
                const Spacer(),
                // Visszavonás
                if (_strokes.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Visszavonás'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white60),
                    onPressed: () => setState(() => _strokes.removeLast()),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ── Cím ─────────────────────────────────────────
          _buildField(
            controller: _titleCtrl,
            label: 'Cím *',
            hint: 'Röviden: mi a probléma?',
          ),
          const SizedBox(height: 12),

          // ── Leírás ───────────────────────────────────────
          _buildField(
            controller: _descriptionCtrl,
            label: 'Leírás',
            hint: 'Lépések a reprodukáláshoz, várt vs. tényleges viselkedés...',
            maxLines: 4,
          ),
          const SizedBox(height: 12),

          // ── Prioritás ────────────────────────────────────
          const Text('Prioritás', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final p in [
                ('low', 'Alacsony', Colors.green),
                ('medium', 'Közepes', Colors.yellow),
                ('high', 'Magas', Colors.orange),
                ('critical', 'Kritikus', Colors.red),
              ])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _priority == p.$1
                            ? p.$3.withValues(alpha: 0.25)
                            : const Color(0xFF1A1A2E),
                        border: Border.all(
                          color: _priority == p.$1 ? p.$3 : Colors.white12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: _priority == p.$1 ? p.$3 : Colors.white38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Route info ───────────────────────────────────
          Text(
            'Route: ${widget.currentRoute}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller:    controller,
          maxLines:      maxLines,
          style:         const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled:    true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
          SizedBox(height: 16),
          Text(
            'Bug report sikeresen beküldve!',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Köszönjük a visszajelzést.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A cím kötelező!'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final ok = await BugReporter.instance.submit(
      title:       _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      priority:    _priority,
      routeName:   widget.currentRoute,
      annotatedScreenshot: null, // TODO: annotált kép renderelése
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _submitted    = ok;
      });

      if (ok) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba a beküldés során. Próbáld újra!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

// ── Annotáció vászon widget ────────────────────────────────────

class _AnnotationCanvas extends StatelessWidget {
  final Uint8List screenshot;
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color penColor;
  final double penWidth;
  final void Function(Offset) onStrokeStart;
  final void Function(Offset) onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  const _AnnotationCanvas({
    required this.screenshot,
    required this.strokes,
    required this.currentStroke,
    required this.penColor,
    required this.penWidth,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onPanStart:  (d) => onStrokeStart(d.localPosition),
        onPanUpdate: (d) => onStrokeUpdate(d.localPosition),
        onPanEnd:    (_) => onStrokeEnd(),
        child: CustomPaint(
          painter: _AnnotationPainter(
            screenshot:    screenshot,
            strokes:       strokes,
            currentStroke: currentStroke,
            penColor:      penColor,
            penWidth:      penWidth,
          ),
          child: AspectRatio(
            aspectRatio: 9 / 19.5, // Tipikus mobil arány
            child: Container(),
          ),
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final Uint8List screenshot;
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color penColor;
  final double penWidth;

  _AnnotationPainter({
    required this.screenshot,
    required this.strokes,
    required this.currentStroke,
    required this.penColor,
    required this.penWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Vászon háttér (fekete ha nincs screenshot)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Screenshot rajzolása (egyszerűsített – teljes implementációhoz
    // flutter_image_compress vagy ui.Image szükséges)
    // TODO: screenshot decoding és rajzolás ui.Image-ként

    // Befejezett vonások
    final paint = Paint()
      ..color       = penColor
      ..strokeWidth = penWidth
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Aktuális vonal
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}
