import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/components/components.dart';
import '../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/translation_extension.dart';
import '../../repositories/auth_repository.dart';

// ============================================================
// AuthScreen – Login / Regisztráció / Jelszó visszaállítás
// ============================================================

class AuthScreen extends StatelessWidget {
  final bool showPasswordReset;

  const AuthScreen({super.key, this.showPasswordReset = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: _AuthView(showPasswordReset: showPasswordReset),
    );
  }
}

class _AuthView extends StatefulWidget {
  final bool showPasswordReset;
  const _AuthView({required this.showPasswordReset});

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  bool _isLogin = true;
  bool _isResetting = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _isFirstSetup = false;
  bool _firstSetupChecked = false;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.showPasswordReset) _isResetting = true;
    _checkFirstSetup();
  }

  Future<void> _checkFirstSetup() async {
    final isFirst = await AuthRepository().isFirstSetup();
    if (!mounted) return;
    setState(() {
      _isFirstSetup = isFirst;
      _firstSetupChecked = true;
      // Ha első indítás, nyissuk rögtön a regisztrációs nézetet
      if (isFirst) _isLogin = false;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (_isResetting) {
      if (email.isEmpty) {
        _snackError(ctx, 'Kérlek add meg az email címedet!');
        return;
      }
      ctx.read<AuthCubit>().resetPassword(email);
      return;
    }

    if (email.isEmpty)    { _snackError(ctx, 'Email cím kötelező!'); return; }
    if (password.isEmpty) { _snackError(ctx, 'Jelszó kötelező!'); return; }
    if (password.length < 6) {
      _snackError(ctx, 'A jelszónak legalább 6 karakter kell!');
      return;
    }
    if (!_isLogin && !_acceptedTerms) {
      _snackError(ctx, 'Fogadd el a felhasználási feltételeket!');
      return;
    }

    if (_isLogin) {
      ctx.read<AuthCubit>().signInWithEmailPassword(email, password);
    } else if (_isFirstSetup) {
      ctx.read<AuthCubit>().registerFirstAdmin(email, password);
    } else {
      ctx.read<AuthCubit>().registerWithEmailPassword(email, password);
    }
  }

  void _snackError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(LucideIcons.triangleAlert, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.error,
    ));
  }

  void _snackInfo(BuildContext ctx, String msg, {Color? color}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? AppColors.success,
    ));
  }

  Future<void> _showDocumentDialog(BuildContext context, String docId) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<dynamic>(
        future: Supabase.instance.client
            .from('legal_documents')
            .select()
            .eq('id', docId)
            .eq('is_active', true)
            .maybeSingle(),
        builder: (ctx2, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              content: const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Hiba'),
              content: const Text('Nem sikerült betölteni a dokumentumot.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('OK'),
                ),
              ],
            );
          }
          final data = snapshot.data as Map;
          final titleLocales = data['title_locales'] as Map? ?? {};
          final contentLocales = data['content_locales'] as Map? ?? {};

          String lang = 'hu';
          try {
            lang = context.currentLang;
          } catch (_) {}


          final title = titleLocales[lang] ?? titleLocales['hu'] ?? docId;
          final content = contentLocales[lang] ?? contentLocales['hu'] ?? '';

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              height: 500,
              child: SingleChildScrollView(
                child: HtmlPreviewWidget(htmlText: content),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Bezárás'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RadialBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (ctx, state) {
                  if (state is AuthError) {
                    _snackError(ctx, state.message);
                  } else if (state is AuthResetSuccess) {
                    _snackInfo(ctx, state.message);
                    setState(() => _isResetting = false);
                  } else if (state is AuthRequiresConfirmation) {
                    _snackInfo(ctx, state.message,
                        color: AppColors.primaryVariant);
                    setState(() {
                      _isLogin = true;
                      _passwordCtrl.clear();
                    });
                  } else if (state is AuthSuccess) {
                    // Jelzés a rendszer jelszókezelőknek (Keychain, 1Password, Bitwarden)
                    TextInput.finishAutofillContext();
                  }
                },
                builder: (ctx, state) {
                  final isLoading = state is AuthLoading;
                  return GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogo(),
                        if (_isFirstSetup) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.shieldCheck,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Első indítás – hozd létre az admin fiókot',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (c, a) =>
                              FadeTransition(opacity: a, child: c),
                          child: _isResetting
                              ? _buildResetForm(ctx, isLoading)
                              : _buildAuthForm(ctx, isLoading),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo / header ───────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryVariant],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(Icons.rocket_launch_rounded,
              size: 32, color: AppColors.onPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Skeleton App', style: AppTypography.titleLarge),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            key: ValueKey(_isResetting
                ? 'r'
                : _isLogin
                    ? 'l'
                    : 'reg'),
            _isResetting
                ? 'Jelszó visszaállítása'
                : _isLogin
                    ? 'Bejelentkezés'
                    : 'Új fiók létrehozása',
            style: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }

  // ── Reset form ──────────────────────────────────────────────
  Widget _buildResetForm(BuildContext ctx, bool isLoading) {
    return Column(
      key: const ValueKey('reset'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add meg az email címedet, és küldünk egy visszaállítási linket.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Email cím',
          hint: 'pelda@email.com',
          prefixIcon: LucideIcons.mail,
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(children: [
          Expanded(
            child: AppButton(
              label: 'Mégsem',
              variant: AppButtonVariant.secondary,
              onTap: () => setState(() => _isResetting = false),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: isLoading ? 'Küldés...' : 'Link küldése',
              icon: LucideIcons.send,
              isLoading: isLoading,
              onTap: isLoading ? null : () => _submit(ctx),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Auth form ───────────────────────────────────────────────
  Widget _buildAuthForm(BuildContext ctx, bool isLoading) {
    return AutofillGroup(
      child: Column(
        key: const ValueKey('auth'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
          AppTextField(
            label: 'Email cím',
            hint: 'pelda@email.com',
            prefixIcon: LucideIcons.mail,
            controller: _emailCtrl,
            focusNode: _emailFocus,
            nextFocusNode: _passFocus,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),

          // Jelszó
          AppTextField(
            label: 'Jelszó',
            hint: '••••••••',
            prefixIcon: LucideIcons.lock,
            controller: _passwordCtrl,
            focusNode: _passFocus,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: _isLogin
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: AppColors.onSurface.withValues(alpha: 0.4),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          // Elfelejtett jelszó
          if (_isLogin) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _isResetting = true),
                child: Text('Elfelejtetted a jelszót?',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.primary)),
              ),
            ),
          ],

          // ÁSZF checkbox (regisztrációnál)
          if (!_isLogin) ...[
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () =>
                  setState(() => _acceptedTerms = !_acceptedTerms),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                      fillColor: WidgetStateProperty.resolveWith((s) =>
                          s.contains(WidgetState.selected)
                              ? AppColors.primary
                              : Colors.transparent),
                      checkColor: AppColors.onPrimary,
                      side: BorderSide(
                          color: AppColors.onSurface.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.bodySmall.copyWith(color: AppColors.onSurface),
                        children: [
                          const TextSpan(text: 'Elfogadom a '),
                          TextSpan(
                            text: 'Felhasználási Feltételeket',
                            style: TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showDocumentDialog(context, 'terms'),
                          ),
                          const TextSpan(text: ' és az '),
                          TextSpan(
                            text: 'Adatvédelmi Nyilatkozatot',
                            style: TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showDocumentDialog(context, 'privacy'),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],


          const SizedBox(height: AppSpacing.lg),

          // Fő gomb
          AppButton(
            label: isLoading
                ? 'Folyamatban...'
                : _isLogin
                    ? 'Bejelentkezés'
                    : 'Fiók létrehozása',
            icon: isLoading ? null : LucideIcons.arrowRight,
            isLoading: isLoading,
            onTap: isLoading ? null : () => _submit(ctx),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Social Login ───────────────────────────────────────
          Row(children: [
            Expanded(child: Divider(color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('vagy', style: AppTypography.bodySmall),
            ),
            Expanded(child: Divider(color: AppColors.divider)),
          ]),
          const SizedBox(height: AppSpacing.md),

          // Google gomb
          _SocialLoginButton(
            label: 'Folytatás Google-lal',
            assetPath: 'assets/icons/google_logo.png',
            fallbackIcon: LucideIcons.chrome,
            isLoading: isLoading,
            onPressed: () => ctx.read<AuthCubit>().signInWithGoogle(),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Apple gomb (csak iOS/macOS-on jelenik meg)
          if (Theme.of(context).platform == TargetPlatform.iOS ||
              Theme.of(context).platform == TargetPlatform.macOS)
            _SocialLoginButton(
              label: 'Folytatás Apple-lel',
              assetPath: 'assets/icons/apple_logo.png',
              fallbackIcon: Icons.apple,
              isLoading: isLoading,
              onPressed: () => ctx.read<AuthCubit>().signInWithApple(),
            ),

          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),

          // Váltógomb
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLogin
                    ? 'Még nincs fiókod? '
                    : 'Már van fiókod? ',
                style: AppTypography.bodySmall,
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _isLogin = !_isLogin;
                  _acceptedTerms = false;
                }),
                child: Text(
                  _isLogin ? 'Regisztrálj' : 'Jelentkezz be',
                  style: AppTypography.label
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Social Login Button ────────────────────────────────────────

class _SocialLoginButton extends StatelessWidget {
  final String label;
  final String assetPath;
  final IconData fallbackIcon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SocialLoginButton({
    required this.label,
    required this.assetPath,
    required this.fallbackIcon,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          backgroundColor: AppColors.surfaceVariant,
        ),
        onPressed: isLoading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo kép, fallback ikonra ha nem létezik az asset
            SizedBox(
              width: 20,
              height: 20,
              child: Image.asset(
                assetPath,
                errorBuilder: (_, __, ___) =>
                    Icon(fallbackIcon, size: 18, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
