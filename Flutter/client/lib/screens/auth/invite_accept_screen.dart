import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/components/components.dart';
import '../../core/theme/app_theme.dart';

// ============================================================
// InviteAcceptScreen – Admin meghívó elfogadása
//
// Elérés: deep link /invite-accept?token=<uuid>
// Validálja a tokent, jelszót kér, majd meghívja az
// admin-invite-accept edge function-t.
// ============================================================

class InviteAcceptScreen extends StatefulWidget {
  final String token;
  const InviteAcceptScreen({super.key, required this.token});

  @override
  State<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends State<InviteAcceptScreen> {
  final _nameCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  final _passFocus  = FocusNode();
  final _pass2Focus = FocusNode();

  bool _obscurePass  = true;
  bool _obscurePass2 = true;
  bool _isLoading    = false;
  bool _isValidating = true;
  bool _tokenValid   = false;
  String? _inviteEmail;
  String? _inviteRole;
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _passFocus.dispose();
    _pass2Focus.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final res = await Supabase.instance.client.rpc(
        'validate_invitation_token',
        params: {'p_token': widget.token},
      );
      final data = res as Map<String, dynamic>;
      setState(() {
        _isValidating = false;
        _tokenValid   = data['valid'] as bool? ?? false;
        _inviteEmail  = data['email'] as String?;
        _inviteRole   = data['role'] as String?;
        if (!_tokenValid) {
          final reason = data['reason'] as String?;
          _error = switch (reason) {
            'already_used' => 'Ez a meghívó link már fel lett használva.',
            'expired'      => 'Ez a meghívó link lejárt.',
            _              => 'Érvénytelen meghívó link.',
          };
        }
      });
    } catch (e) {
      setState(() {
        _isValidating = false;
        _tokenValid   = false;
        _error        = 'Token ellenőrzése sikertelen: $e';
      });
    }
  }

  Future<void> _submit() async {
    final password = _passCtrl.text;
    final pass2    = _pass2Ctrl.text;
    final name     = _nameCtrl.text.trim();

    if (password.length < 8) {
      setState(() => _error = 'A jelszónak legalább 8 karakter kell!');
      return;
    }
    if (password != pass2) {
      setState(() => _error = 'A két jelszó nem egyezik!');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-invite-accept',
        body: {
          'token':        widget.token,
          'password':     password,
          'display_name': name.isEmpty ? null : name,
        },
      );

      if (response.status == 200 || response.status == 201) {
        setState(() { _isLoading = false; _done = true; });
      } else {
        final data = response.data as Map<String, dynamic>?;
        setState(() {
          _isLoading = false;
          _error = data?['error'] as String? ?? 'Regisztráció sikertelen.';
        });
      }
    } catch (e) {
      setState(() { _isLoading = false; _error = 'Hiba: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RadialBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isValidating) {
      return const Column(mainAxisSize: MainAxisSize.min, children: [
        AppLoadingIndicator(),
        SizedBox(height: 16),
        Text('Meghívó ellenőrzése…'),
      ]);
    }

    if (_done) return _buildSuccessView();
    if (!_tokenValid) return _buildErrorView();
    return _buildForm();
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 56),
          const SizedBox(height: 20),
          Text('Admin regisztráció', style: AppTypography.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Meghívott e-mail: ${_inviteEmail ?? ''}',
            style: AppTypography.bodySmall.copyWith(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          Text(
            'Szerepkör: ${_inviteRole ?? 'admin'}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Megjelenített név
          AppTextField(
            controller: _nameCtrl,
            label: 'Megjelenített név (opcionális)',
            hint: 'Pl. Kiss Péter',
            autofillHints: const [AutofillHints.name],
            nextFocusNode: _passFocus,
          ),
          const SizedBox(height: AppSpacing.md),

          // Jelszó
          AppTextField(
            controller: _passCtrl,
            label: 'Jelszó',
            hint: 'Min. 8 karakter',
            obscureText: _obscurePass,
            focusNode: _passFocus,
            nextFocusNode: _pass2Focus,
            autofillHints: const [AutofillHints.newPassword],
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Jelszó megerősítése
          AppTextField(
            controller: _pass2Ctrl,
            label: 'Jelszó újra',
            hint: 'Azonos legyen a fentivel',
            obscureText: _obscurePass2,
            focusNode: _pass2Focus,
            autofillHints: const [AutofillHints.newPassword],
            suffixIcon: IconButton(
              icon: Icon(_obscurePass2 ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18),
              onPressed: () => setState(() => _obscurePass2 = !_obscurePass2),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(LucideIcons.triangleAlert, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: TextStyle(color: AppColors.error, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Regisztráció & Belépés',
            isLoading: _isLoading,
            icon: LucideIcons.userCheck,
            onTap: _isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.shieldX, color: AppColors.error, size: 56),
      const SizedBox(height: 20),
      Text('Érvénytelen meghívó', style: AppTypography.titleLarge,
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(_error ?? 'Ismeretlen hiba.',
          style: AppTypography.bodyMedium.copyWith(color: Colors.white54),
          textAlign: TextAlign.center),
    ]);
  }

  Widget _buildSuccessView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.circleCheck, color: AppColors.success, size: 56),
      const SizedBox(height: 20),
      Text('Regisztráció sikeres!', style: AppTypography.titleLarge,
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(
        'Admin fiókodat létrehoztuk. Most már bejelentkezhetsz az admin felületre.',
        style: AppTypography.bodyMedium.copyWith(color: Colors.white54),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      AppButton(
        label: 'Bejelentkezés',
        icon: LucideIcons.logIn,
        onTap: () {
          // Navigálás vissza az AuthScreen-re
          Navigator.of(context).pushReplacementNamed('/');
        },
      ),
    ]);
  }
}
