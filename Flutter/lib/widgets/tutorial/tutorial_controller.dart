import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// TutorialController – Tutorial állapot kezelő  [M8]
//
// Felelős:
//  - Melyik tutorial van aktív
//  - Lépések kezelése
//  - SharedPreferences alapú mentés (képernyő ID-nként)
//
// Minden képernyőn, ahol tutorial kell:
//   1. Hozz létre egy TutorialController-t az initState-ben
//   2. Csatold a TutorialStep-eket a widgetekhez GlobalKey-ekkel
//   3. Jelenítsd meg a TutorialOverlay-t
// ============================================================

/// Egy tutorial lépés leírója
class TutorialStep {
  /// A célzott widget GlobalKey-e (ez köré rajzolja a kiemelést)
  final GlobalKey targetKey;

  /// Lokalizált cím kulcsa (AppLocalizations-ből kerül lekérésre)
  final String titleLocKey;

  /// Lokalizált leírás kulcsa
  final String descriptionLocKey;

  /// Buborék pozíciója a célzott widgethez képest
  final TutorialBubblePosition position;

  const TutorialStep({
    required this.targetKey,
    required this.titleLocKey,
    required this.descriptionLocKey,
    this.position = TutorialBubblePosition.below,
  });
}

enum TutorialBubblePosition { above, below, left, right }

// ── Controller ─────────────────────────────────────────────────

class TutorialController extends ChangeNotifier {
  final String screenId;
  final List<TutorialStep> steps;

  int _currentIndex = 0;
  bool _isActive    = false;
  bool _isLoaded    = false;

  TutorialController({
    required this.screenId,
    required this.steps,
  });

  // ── Getterek ─────────────────────────────────────────────

  bool get isActive      => _isActive;
  bool get isLoaded      => _isLoaded;
  int  get currentIndex  => _currentIndex;
  bool get isFirst       => _currentIndex == 0;
  bool get isLast        => _currentIndex == steps.length - 1;

  TutorialStep? get currentStep =>
      (_isActive && steps.isNotEmpty && _currentIndex < steps.length)
          ? steps[_currentIndex]
          : null;

  double get progress =>
      steps.isEmpty ? 1.0 : (_currentIndex + 1) / steps.length;

  // ── Életciklus ────────────────────────────────────────────

  /// Automatikus indítás: ha még nem futott le, megmutatja a tutorialt.
  Future<void> startIfNotSeen() async {
    final seen = await _isSeen();
    if (!seen && steps.isNotEmpty) {
      _currentIndex = 0;
      _isActive     = true;
      notifyListeners();
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Kézi (újra)indítás – pl. "Tutorial újraindítása" gombra
  Future<void> forceStart() async {
    await _markUnseen();
    _currentIndex = 0;
    _isActive     = true;
    _isLoaded     = true;
    notifyListeners();
  }

  // ── Navigáció ─────────────────────────────────────────────

  void next() {
    if (_currentIndex < steps.length - 1) {
      _currentIndex++;
      notifyListeners();
    } else {
      finish();
    }
  }

  void previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void skip() => finish();

  Future<void> finish() async {
    _isActive = false;
    notifyListeners();
    await _markSeen();
  }

  // ── SharedPreferences ─────────────────────────────────────

  String get _prefsKey => 'tutorial_seen_$screenId';

  Future<bool> _isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  Future<void> _markUnseen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ── Statikus utility ─────────────────────────────────────

  /// Az összes tutorial visszaállítása (Beállítások → "Tutorial újraindítása")
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys()
        .where((k) => k.startsWith('tutorial_seen_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Egy adott képernyő tutorial-jának visszaállítása
  static Future<void> resetScreen(String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tutorial_seen_$screenId');
  }
}
