import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/components/components.dart';
import '../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/translation_extension.dart';
import '../../blocs/translation/translation_cubit.dart';


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

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.showPasswordReset) _isResetting = true;
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
        _snackError(ctx, ctx.t('auth.err_email_empty', 'Kérlek add meg az email címedet!'));
        return;
      }
      ctx.read<AuthCubit>().resetPassword(email);
      return;
    }

    if (email.isEmpty)    { _snackError(ctx, ctx.t('auth.err_email_required', 'Email cím kötelező!')); return; }
    if (password.isEmpty) { _snackError(ctx, ctx.t('auth.err_password_required', 'Jelszó kötelező!')); return; }
    if (password.length < 6) {
      _snackError(ctx, ctx.t('auth.err_password_too_short', 'A jelszónak legalább 6 karakter kell!'));
      return;
    }
    if (!_isLogin && !_acceptedTerms) {
      _snackError(ctx, ctx.t('auth.err_accept_terms', 'Fogadd el a felhasználási feltételeket!'));
      return;
    }

    if (_isLogin) {
      ctx.read<AuthCubit>().signInWithEmailPassword(email, password);
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
              title: Text(context.t('auth.error', 'Hiba')),
              content: Text(context.t('auth.err_load_doc_failed', 'Nem sikerült betölteni a dokumentumot.')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: Text(context.t('ui.ok', 'OK')),
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
                child: Text(context.t('ui.close', 'Bezárás')),
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
                  }
                },
                builder: (ctx, state) {
                  final isLoading = state is AuthLoading;
                  return GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLogo(ctx),
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
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _buildLanguageSelector(ctx),
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

  // ── Nyelvi választó ───────────────────────────────────────────
  Widget _buildLanguageSelector(BuildContext context) {
    final langCode = context.currentLang;
    final flag = langCode == 'hu'
        ? '🇭🇺'
        : langCode == 'en'
            ? '🇬🇧'
            : '🇩🇪';

    return PopupMenuButton<String>(
      tooltip: context.t('auth.select_language', 'Nyelv választása'),
      onSelected: (String code) {
        context.read<TranslationCubit>().loadTranslations(code);
      },
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              langCode.toUpperCase(),
              style: AppTypography.label.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'hu',
          child: Row(
            children: [
              const Text('🇭🇺', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Magyar',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              const Text('🇬🇧', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'English',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'de',
          child: Row(
            children: [
              const Text('🇩🇪', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Deutsch',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Logo / header ───────────────────────────────────────────
  Widget _buildLogo(BuildContext context) {
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
        Text(context.t('auth.logo_title', 'Skeleton App'), style: AppTypography.titleLarge),
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
                ? context.t('auth.reset_password', 'Jelszó visszaállítása')
                : _isLogin
                    ? context.t('auth.login', 'Bejelentkezés')
                    : context.t('auth.register', 'Új fiók létrehozása'),
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
          ctx.t('auth.reset_info', 'Add meg az email címedet, és küldünk egy visszaállítási linket.'),
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: ctx.t('auth.email_label', 'Email cím'),
          hint: ctx.t('auth.email_hint', 'pelda@email.com'),
          prefixIcon: LucideIcons.mail,
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(children: [
          Expanded(
            child: AppButton(
              label: ctx.t('ui.cancel', 'Mégsem'),
              variant: AppButtonVariant.secondary,
              onTap: () => setState(() => _isResetting = false),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: isLoading ? ctx.t('auth.sending', 'Küldés...') : ctx.t('auth.send_link', 'Link küldése'),
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
            label: ctx.t('auth.email_label', 'Email cím'),
            hint: ctx.t('auth.email_hint', 'pelda@email.com'),
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
            label: ctx.t('auth.password_label', 'Jelszó'),
            hint: ctx.t('auth.password_hint', '••••••••'),
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
                child: Text(
                  ctx.t('auth.forgot_password', 'Elfelejtetted a jelszót?'),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                ),
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
                          TextSpan(text: ctx.t('auth.accept_terms_prefix', 'Elfogadom a ')),
                          TextSpan(
                            text: ctx.t('auth.terms_service', 'Felhasználási Feltételeket'),
                            style: TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showDocumentDialog(context, 'terms'),
                          ),
                          TextSpan(text: ctx.t('auth.accept_terms_middle', ' és az ')),
                          TextSpan(
                            text: ctx.t('auth.privacy_policy', 'Adatvédelmi Nyilatkozatot'),
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
                ? ctx.t('auth.processing', 'Folyamatban...')
                : _isLogin
                    ? ctx.t('auth.login', 'Bejelentkezés')
                    : ctx.t('auth.create_account', 'Fiók létrehozása'),
            icon: isLoading ? null : LucideIcons.arrowRight,
            isLoading: isLoading,
            onTap: isLoading ? null : () => _submit(ctx),
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
                    ? ctx.t('auth.no_account', 'Még nincs fiókod? ')
                    : ctx.t('auth.has_account', 'Már van fiókod? '),
                style: AppTypography.bodySmall,
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _isLogin = !_isLogin;
                  _acceptedTerms = false;
                }),
                child: Text(
                  _isLogin ? ctx.t('auth.register_action', 'Regisztrálj') : ctx.t('auth.login_action', 'Jelentkezz be'),
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
