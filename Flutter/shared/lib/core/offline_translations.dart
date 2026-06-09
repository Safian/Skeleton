/// Offline fallback translations for keys that must be readable before the
/// remote translation table is fetched (boot, login screen, critical errors).
///
/// Add keys here whenever a UI string needs to appear before [TranslationCubit]
/// has loaded. Keys mirror the `translations` DB table key column.
class OfflineTranslations {
  OfflineTranslations._();

  static const Map<String, Map<String, String>> _data = {
    'hu': {
      // General
      'app_name': 'Skeleton',
      'ok': 'Ok',
      'cancel': 'Mégse',
      'save': 'Mentés',
      'delete': 'Törlés',
      'close': 'Bezárás',
      'back': 'Vissza',
      'next': 'Tovább',
      'loading': 'Betöltés...',
      'error': 'Hiba',
      'retry': 'Újra',
      'yes': 'Igen',
      'no': 'Nem',
      'search': 'Keresés',
      'settings': 'Beállítások',
      'logout': 'Kijelentkezés',
      // Auth
      'login': 'Bejelentkezés',
      'login_email': 'E-mail cím',
      'login_password': 'Jelszó',
      'login_button': 'Bejelentkezés',
      'login_forgot_password': 'Elfelejtett jelszó',
      'login_error_invalid': 'Hibás e-mail cím vagy jelszó.',
      'login_error_generic': 'Bejelentkezési hiba. Kérjük próbáld újra.',
      // Maintenance
      'maintenance_title': 'Karbantartás',
      'maintenance_body': 'Az alkalmazás átmeneti karbantartás alatt áll. Hamarosan visszatérünk!',
      // Update required
      'update_required_title': 'Frissítés szükséges',
      'update_required_body': 'Az alkalmazás elavult verzióját használod. Kérjük frissítsd az app store-ból.',
      'update_required_button': 'Frissítés',
      // Session / errors
      'session_expired': 'A munkamenet lejárt. Kérjük jelentkezz be újra.',
      'account_deleted': 'A fiókod törölve lett.',
      'role_changed': 'A fiókod jogosultsága megváltozott. Kérjük jelentkezz be újra.',
      // Legal
      'legal_accept_title': 'Feltételek elfogadása',
      'legal_accept_body': 'Az alkalmazás használatához el kell fogadnod a frissített feltételeket.',
      'legal_accept_button': 'Elfogadom',
    },
    'en': {
      // General
      'app_name': 'Skeleton',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'close': 'Close',
      'back': 'Back',
      'next': 'Next',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'yes': 'Yes',
      'no': 'No',
      'search': 'Search',
      'settings': 'Settings',
      'logout': 'Logout',
      // Auth
      'login': 'Login',
      'login_email': 'Email address',
      'login_password': 'Password',
      'login_button': 'Login',
      'login_forgot_password': 'Forgot password',
      'login_error_invalid': 'Invalid email or password.',
      'login_error_generic': 'Login error. Please try again.',
      // Maintenance
      'maintenance_title': 'Maintenance',
      'maintenance_body': 'The app is temporarily down for maintenance. We\'ll be back soon!',
      // Update required
      'update_required_title': 'Update Required',
      'update_required_body': 'You\'re using an outdated version. Please update from the app store.',
      'update_required_button': 'Update',
      // Session / errors
      'session_expired': 'Your session has expired. Please log in again.',
      'account_deleted': 'Your account has been deleted.',
      'role_changed': 'Your account permissions changed. Please log in again.',
      // Legal
      'legal_accept_title': 'Accept Terms',
      'legal_accept_body': 'You must accept the updated terms to use this app.',
      'legal_accept_button': 'Accept',
    },
    'de': {
      // General
      'app_name': 'Skeleton',
      'ok': 'OK',
      'cancel': 'Abbrechen',
      'save': 'Speichern',
      'delete': 'Löschen',
      'close': 'Schließen',
      'back': 'Zurück',
      'next': 'Weiter',
      'loading': 'Laden...',
      'error': 'Fehler',
      'retry': 'Nochmal',
      'yes': 'Ja',
      'no': 'Nein',
      'search': 'Suchen',
      'settings': 'Einstellungen',
      'logout': 'Abmelden',
      // Auth
      'login': 'Anmelden',
      'login_email': 'E-Mail-Adresse',
      'login_password': 'Passwort',
      'login_button': 'Anmelden',
      'login_forgot_password': 'Passwort vergessen',
      'login_error_invalid': 'Ungültige E-Mail-Adresse oder Passwort.',
      'login_error_generic': 'Anmeldefehler. Bitte versuche es erneut.',
      // Maintenance
      'maintenance_title': 'Wartung',
      'maintenance_body': 'Die App befindet sich vorübergehend in Wartung. Wir sind bald zurück!',
      // Update required
      'update_required_title': 'Update erforderlich',
      'update_required_body': 'Du verwendest eine veraltete Version. Bitte aktualisiere im App Store.',
      'update_required_button': 'Aktualisieren',
      // Session / errors
      'session_expired': 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
      'account_deleted': 'Dein Konto wurde gelöscht.',
      'role_changed': 'Deine Kontoberechtigungen wurden geändert. Bitte melde dich erneut an.',
      // Legal
      'legal_accept_title': 'Bedingungen akzeptieren',
      'legal_accept_body': 'Du musst die aktualisierten Bedingungen akzeptieren, um die App zu nutzen.',
      'legal_accept_button': 'Akzeptieren',
    },
  };

  /// Returns the translation for [key] in [lang], or null if not found.
  static String? get(String key, String lang) {
    return _data[lang]?[key] ?? _data['hu']?[key];
  }
}
