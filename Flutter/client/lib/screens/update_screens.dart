import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/session/session_cubit.dart';
import '../core/components/components.dart';
import '../core/theme/app_theme.dart';

// ============================================================
// update_screens.dart  [M3.1]
//
// SoftUpdateScreen  – ajánlott frissítés (átugorható)
// ForceUpdateScreen – kötelező frissítés (nem átugorható)
// ============================================================

// ── SoftUpdateScreen ─────────────────────────────────────────

class SoftUpdateScreen extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String storeUrl;

  const SoftUpdateScreen({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.storeUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(LucideIcons.arrowUpCircle, size: 72, color: AppColors.primary),
              const SizedBox(height: 32),
              Text(
                'Új verzió érhető el',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A $latestVersion verzió letölthető. Jelenleg a $currentVersion fut.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.onBackground.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              AppButton(
                label: 'Frissítés most',
                icon: LucideIcons.download,
                onTap: () => _openStore(context),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Később',
                variant: AppButtonVariant.ghost,
                onTap: () => context.read<SessionCubit>().skipSoftUpdate(),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.tryParse(storeUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── ForceUpdateScreen ─────────────────────────────────────────

class ForceUpdateScreen extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;
  final String storeUrl;

  const ForceUpdateScreen({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
    required this.storeUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(LucideIcons.alertTriangle, size: 72, color: AppColors.warning),
              const SizedBox(height: 32),
              Text(
                'Frissítés szükséges',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Az alkalmazás ezen verziója ($currentVersion) már nem támogatott.\n'
                'A folytatáshoz szükséges minimális verzió: $requiredVersion.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.onBackground.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              AppButton(
                label: 'Frissítés most',
                icon: LucideIcons.download,
                onTap: () => _openStore(context),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.tryParse(storeUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
