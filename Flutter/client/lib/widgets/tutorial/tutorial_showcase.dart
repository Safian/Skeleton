import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../services/tutorial_service.dart';

// ============================================================
// tutorial_showcase.dart  [M4.2]
//
// Showcase-alapú tutorial rendszer segédeszközei.
//
// Használat egy képernyőn:
//
//   class _MyScreenState extends State<MyScreen> {
//     final _key1 = GlobalKey();
//     final _key2 = GlobalKey();
//
//     @override
//     void initState() {
//       super.initState();
//       TutorialAutoLaunch.schedule(
//         context: context,
//         screenId: 'my_screen',
//         keys: [_key1, _key2],
//       );
//     }
//
//     @override
//     Widget build(BuildContext context) {
//       return ShowCaseWidget(
//         builder: (ctx) => Scaffold(
//           body: TutorialStep(
//             globalKey: _key1,
//             title: AppLocalizations.of(ctx).tutorial_home_welcome_title,
//             description: AppLocalizations.of(ctx).tutorial_home_welcome_desc,
//             child: MyWidget(),
//           ),
//         ),
//       );
//     }
//   }
// ============================================================

// ── TutorialStep – egyetlen lépés wrapper ────────────────────

class TutorialStep extends StatelessWidget {
  /// A showcase GlobalKey – ugyanaz, amit a ShowCaseWidget.of(ctx).startShowCase()-nek adunk.
  final GlobalKey globalKey;
  final String title;
  final String description;
  final Widget child;

  /// Ha true, kör alakú kiemelés; ha false, szögletes.
  final bool shapeCirle;

  const TutorialStep({
    super.key,
    required this.globalKey,
    required this.title,
    required this.description,
    required this.child,
    this.shapeCirle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: globalKey,
      title: title,
      description: description,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      descTextStyle: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
      ),
      tooltipBackgroundColor: const Color(0xFF1E1E3F),
      overlayOpacity: 0.7,
      child: child,
    );
  }
}

// ── TutorialAutoLaunch – automatikus indítás initState-ből ───

class TutorialAutoLaunch {
  /// Beütemezi a tutorial elindítását az első frame után.
  /// Ha a tutorial már volt futtatva (SharedPrefs), nem indul el.
  static void schedule({
    required BuildContext context,
    required String screenId,
    required List<GlobalKey> keys,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await TutorialService.instance.hasSeenTutorial(screenId);
      if (seen) return;
      if (!context.mounted) return;

      await TutorialService.instance.markSeen(screenId);
      ShowCaseWidget.of(context).startShowCase(keys);
    });
  }
}

// ── ShowCaseWrapper – kényelmi wrapper ──────────────────────
/// A képernyő build() metódusban kell körbevenni a Scaffold-ot.
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return ShowCaseWrapper(
///     onFinish: () { /* opcionális callback */ },
///     builder: (ctx) => Scaffold(...),
///   );
/// }
/// ```
class ShowCaseWrapper extends StatelessWidget {
  final Widget Function(BuildContext ctx) builder;
  final VoidCallback? onFinish;

  const ShowCaseWrapper({
    super.key,
    required this.builder,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: onFinish,
      builder: builder,
    );
  }
}
