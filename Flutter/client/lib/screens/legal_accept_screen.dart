import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeleton_shared/skeleton_shared.dart';
import '../blocs/session/session_cubit.dart';
import '../blocs/session/session_state.dart';

/// Shown when the user has pending legal documents to accept after login.
/// Accepts all documents in sequence before allowing app access.
class LegalAcceptScreen extends StatefulWidget {
  final SessionAcceptLegal state;
  const LegalAcceptScreen({super.key, required this.state});

  @override
  State<LegalAcceptScreen> createState() => _LegalAcceptScreenState();
}

class _LegalAcceptScreenState extends State<LegalAcceptScreen> {
  int _currentIndex = 0;
  bool _accepting = false;

  LegalDocument get _current => widget.state.pendingDocuments[_currentIndex];
  int get _total => widget.state.pendingDocuments.length;

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await context.read<SessionCubit>().acceptDocument(
        _current.id,
        _current.version,
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const lang = 'hu';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _current.localizedTitle(lang),
          style: AppTypography.titleMedium,
        ),
        bottom: _total > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _total,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _current.localizedContent(lang),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  if (_total > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_currentIndex + 1} / $_total',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  AppButton(
                    label: 'Elfogadom',
                    onTap: _accepting ? null : _accept,
                    isLoading: _accepting,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _accepting
                        ? null
                        : () => context.read<SessionCubit>().signOut(),
                    child: Text(
                      'Kijelentkezés',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
