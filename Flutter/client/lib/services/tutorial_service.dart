import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// TutorialService  [M4.2]
//
// SharedPreferences-alapú "láttam-e már" állapot kezelő.
// Minden képernyő egyedi screen_id-vel regisztráltatja magát.
//
// API:
//   await TutorialService.instance.hasSeenTutorial('home')   → bool
//   await TutorialService.instance.markSeen('home')
//   await TutorialService.instance.resetAll()
// ============================================================

class TutorialService {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  static const String _prefix = 'tutorial_seen_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// True ha a felhasználó már látta a tutorial-t ezen a képernyőn.
  Future<bool> hasSeenTutorial(String screenId) async {
    final prefs = await _getPrefs();
    return prefs.getBool('$_prefix$screenId') ?? false;
  }

  /// Megjelöli, hogy a tutorial le lett futtatva ezen a képernyőn.
  Future<void> markSeen(String screenId) async {
    final prefs = await _getPrefs();
    await prefs.setBool('$_prefix$screenId', true);
  }

  /// Minden tutorial állapotának törlése (Beállítások → Tutorial újraindítás).
  Future<void> resetAll() async {
    final prefs = await _getPrefs();
    final keys  = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
