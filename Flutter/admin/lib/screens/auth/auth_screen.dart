import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/components/components.dart';
import '../../core/theme/app_theme.dart';
import '../../core/translation_extension.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';

// ============================================================
// Admin AuthScreen – Login / Jelszó visszaállítás
// Regisztráció szándékosan nincs – admin fiókot manuálisan
// kell létrehozni és a role-t 'admin'-ra állítani.
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
  bool _isResetting = false;
  bool _obscurePassword = true;

  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.showPasswordReset) _isResetting = true;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (_isResetting) {
      if (email.isEmpty) { _err(ctx, ctx.t('auth.err_email_required', 'Email cím kötelező!')); return; }
      ctx.read<AuthCubit>().resetPassword(email);
      return;
    }

    if (email.isEmpty)    { _err(ctx, ctx.t('auth.err_email_required', 'Email cím kötelező!')); return; }
    if (password.isEmpty) { _err(ctx, ctx.t('auth.err_password_required', 'Jelszó kötelező!')); return; }
    if (password.length < 6) { _err(ctx, ctx.t('auth.err_password_too_short', 'A jelszónak legalább 6 karakter kell!')); return; }

    ctx.read<AuthCubit>().signInWithEmailPassword(email, password);
  }

  void _err(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ));
  }

  String _authErrorText(BuildContext ctx, AuthError e) {
    switch (e.type) {
      case AuthErrorType.invalidCredentials:
        return ctx.t('auth.err_invalid_credentials', 'Hibás email cím vagy jelszó.');
      case AuthErrorType.emailNotConfirmed:
        return ctx.t('auth.err_email_not_confirmed', 'Erősítsd meg az email címedet a belépés előtt.');
      case AuthErrorType.alreadyRegistered:
        return ctx.t('auth.err_already_registered', 'Ez az email cím már regisztrálva van.');
      case AuthErrorType.rateLimit:
        return ctx.t('auth.err_rate_limit', 'Túl sok próbálkozás. Kérjük, várj egy kicsit.');
      case AuthErrorType.unknown:
        return e.rawMessage ?? '';
    }
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
                  if (state is AuthError) _err(ctx, _authErrorText(ctx, state));
                  if (state is AuthResetSuccess) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(ctx.t('auth.reset_email_sent',
                          'Jelszó-visszaállítási linket küldtünk az email címedre.')),
                      backgroundColor: AppColors.success,
                    ));
                    setState(() => _isResetting = false);
                  }
                },
                builder: (ctx, state) {
                  final loading = state is AuthLoading;
                  return GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Column(children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryVariant],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded,
                                size: 32, color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(ctx.t('auth.panel_title', 'Admin Panel'),
                              style: AppTypography.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            _isResetting
                                ? ctx.t('auth.reset_password', 'Jelszó visszaállítása')
                                : ctx.t('auth.login', 'Bejelentkezés'),
                            style: AppTypography.bodySmall,
                          ),
                        ]),
                        const SizedBox(height: AppSpacing.xl),

                        if (_isResetting) ...[
                          // Reset form
                          AppTextField(
                            label: ctx.t('auth.email_label', 'Email cím'),
                            hint: ctx.t('auth.email_hint', 'admin@example.com'),
                            prefixIcon: LucideIcons.mail,
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(children: [
                            Expanded(child: AppButton(
                              label: ctx.t('ui.cancel', 'Mégsem'),
                              variant: AppButtonVariant.secondary,
                              onTap: () => setState(() => _isResetting = false),
                            )),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: AppButton(
                              label: loading
                                  ? ctx.t('auth.sending', 'Küldés...')
                                  : ctx.t('auth.send_link', 'Link küldése'),
                              icon: LucideIcons.send,
                              isLoading: loading,
                              onTap: loading ? null : () => _submit(ctx),
                            )),
                          ]),
                        ] else ...[
                          // Login form
                          AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTextField(
                                  label: ctx.t('auth.email_label', 'Email cím'),
                                  hint: ctx.t('auth.email_hint', 'admin@example.com'),
                                  prefixIcon: LucideIcons.mail,
                                  controller: _emailCtrl,
                                  focusNode: _emailFocus,
                                  nextFocusNode: _passFocus,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppTextField(
                                  label: ctx.t('auth.password_label', 'Jelszó'),
                                  hint: '••••••••',
                                  prefixIcon: LucideIcons.lock,
                                  controller: _passCtrl,
                                  focusNode: _passFocus,
                                  obscureText: _obscurePassword,
                                  autofillHints: const [AutofillHints.password],
                                  onChanged: (_) => setState(() {}),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                                      size: 18,
                                      color: AppColors.onSurface.withValues(alpha: 0.4),
                                    ),
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _isResetting = true),
                                    child: Text(
                                        ctx.t('auth.forgot_password', 'Elfelejtetted a jelszót?'),
                                        style: AppTypography.bodySmall
                                            .copyWith(color: AppColors.primary)),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppButton(
                                  label: loading
                                      ? ctx.t('auth.processing', 'Folyamatban...')
                                      : ctx.t('auth.login_button', 'Bejelentkezés'),
                                  icon: loading ? null : LucideIcons.arrowRight,
                                  isLoading: loading,
                                  onTap: loading ? null : () => _submit(ctx),
                                ),
                              ],
                            ),
                          ),
                        ],
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
}
