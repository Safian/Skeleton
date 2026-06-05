const Map<String, Map<String, String>> codebaseTranslations = {
  'auth.logo_title': {'hu': 'Skeleton App', 'en': 'Skeleton App'},
  'auth.reset_password': {'hu': 'Jelszó visszaállítása', 'en': 'Reset Password'},
  'auth.login': {'hu': 'Bejelentkezés', 'en': 'Login'},
  'auth.register': {'hu': 'Új fiók létrehozása', 'en': 'Register'},
  'auth.reset_info': {'hu': 'Add meg az email címedet, és küldünk egy visszaállítási linket.', 'en': 'Enter your email address and we will send you a reset link.'},
  'auth.email_label': {'hu': 'Email cím', 'en': 'Email Address'},
  'auth.email_hint': {'hu': 'pelda@email.com', 'en': 'example@email.com'},
  'auth.password_label': {'hu': 'Jelszó', 'en': 'Password'},
  'auth.password_hint': {'hu': '••••••••', 'en': '••••••••'},
  'auth.forgot_password': {'hu': 'Elfelejtetted a jelszót?', 'en': 'Forgot password?'},
  'auth.accept_terms_prefix': {'hu': 'Elfogadom a ', 'en': 'I accept the '},
  'auth.terms_service': {'hu': 'Felhasználási Feltételeket', 'en': 'Terms of Service'},
  'auth.accept_terms_middle': {'hu': ' és az ', 'en': ' and the '},
  'auth.privacy_policy': {'hu': 'Adatvédelmi Nyilatkozatot', 'en': 'Privacy Policy'},
  'auth.processing': {'hu': 'Folyamatban...', 'en': 'Processing...'},
  'auth.create_account': {'hu': 'Fiók létrehozása', 'en': 'Create Account'},
  'auth.no_account': {'hu': 'Még nincs fiókod? ', 'en': 'Don\'t have an account yet? '},
  'auth.has_account': {'hu': 'Már van fiókod? ', 'en': 'Already have an account? '},
  'auth.register_action': {'hu': 'Regisztrálj', 'en': 'Register'},
  'auth.login_action': {'hu': 'Jelentkezz be', 'en': 'Log in'},
  'auth.err_email_empty': {'hu': 'Kérlek add meg az email címedet!', 'en': 'Please enter your email address!'},
  'auth.err_email_required': {'hu': 'Email cím kötelező!', 'en': 'Email address is required!'},
  'auth.err_password_required': {'hu': 'Jelszó kötelező!', 'en': 'Password is required!'},
  'auth.err_password_too_short': {'hu': 'A jelszónak legalább 8 karakter kell!', 'en': 'Password must be at least 8 characters!'},
  'auth.err_accept_terms': {'hu': 'Fogadd el a felhasználási feltételeket!', 'en': 'Please accept the terms and conditions!'},
  'auth.error': {'hu': 'Hiba', 'en': 'Error'},
  'auth.err_load_doc_failed': {'hu': 'Nem sikerült betölteni a dokumentumot.', 'en': 'Failed to load document.'},
  'auth.select_language': {'hu': 'Nyelv választása', 'en': 'Select Language'},
  'ui.ok': {'hu': 'OK', 'en': 'OK'},
  'ui.close': {'hu': 'Bezárás', 'en': 'Close'},
  'ui.cancel': {'hu': 'Mégsem', 'en': 'Cancel'},
  'auth.sending': {'hu': 'Küldés...', 'en': 'Sending...'},
  'auth.send_link': {'hu': 'Link küldése', 'en': 'Send Link'},

  // ── Admin login / pre-login képernyők (offline elérhető) ──────────────────
  'auth.panel_title': {'hu': 'Admin Panel', 'en': 'Admin Panel'},
  'auth.login_button': {'hu': 'Bejelentkezés', 'en': 'Sign in'},
  'auth.logout': {'hu': 'Kijelentkezés', 'en': 'Sign out'},
  'auth.reset_email_sent': {
    'hu': 'Jelszó-visszaállítási linket küldtünk az email címedre.',
    'en': 'We\'ve sent a password reset link to your email.'
  },
  'auth.err_invalid_credentials': {'hu': 'Hibás email cím vagy jelszó.', 'en': 'Invalid email or password.'},
  'auth.err_email_not_confirmed': {
    'hu': 'Erősítsd meg az email címedet a belépés előtt.',
    'en': 'Please confirm your email address before signing in.'
  },
  'auth.err_already_registered': {'hu': 'Ez az email cím már regisztrálva van.', 'en': 'This email address is already registered.'},
  'auth.err_rate_limit': {'hu': 'Túl sok próbálkozás. Kérjük, várj egy kicsit.', 'en': 'Too many attempts. Please wait a moment.'},

  // ── Maintenance ───────────────────────────────────────────────────────────
  'maintenance.title': {'hu': 'Karbantartás alatt', 'en': 'Under maintenance'},
  'maintenance.body': {'hu': 'Próbáld meg később.', 'en': 'Please try again later.'},

  // ── Access denied ─────────────────────────────────────────────────────────
  'access_denied.title': {'hu': 'Hozzáférés megtagadva', 'en': 'Access denied'},
  'access_denied.body': {
    'hu': 'Ez a felület kizárólag adminisztrátorok számára érhető el.',
    'en': 'This interface is available to administrators only.'
  },
};
