import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../core/theme/app_theme.dart';
import '../core/components/components.dart';

// ============================================================
// UpdateRequiredScreen – Force / Soft Update képernyő  [M5]
//
// Force update esetén: blokkoló, csak az Áruházba lépés lehetséges.
// Soft update esetén: figyelmeztetés, de el lehet utasítani.
// ============================================================

class UpdateRequiredScreen extends StatelessWidget {
  /// Ha false → soft update (elutasítható), ha true → force update (blokkoló)
  final bool isForce;
  final VoidCallback? onSkip;

  const UpdateRequiredScreen({
    super.key,
    required this.isForce,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RadialBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: BlocBuilder<ConfigCubit, ConfigState>(
                builder: (context, configState) {
                  final config = configState.config;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ikon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.arrowUpCircle,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      Text(
                        isForce
                            ? 'Frissítés szükséges'
                            : 'Új verzió elérhető',
                        style: AppTypography.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Text(
                        isForce
                            ? 'Az alkalmazás futtatásához kötelező a legfrissebb verzió telepítése. Kérjük frissítsd az áruházból.'
                            : 'Elérhető egy újabb verzió. Javasoljuk a frissítést a legjobb élmény érdekében.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onBackground.withValues(alpha: 0.7),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Frissítés gomb
                      AppButton(
                        label: 'Frissítés az áruházból',
                        icon: LucideIcons.externalLink,
                        onTap: () => _openStore(context, config),
                      ),

                      // Soft update esetén "Most nem" gomb
                      if (!isForce && onSkip != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Most nem',
                          variant: AppButtonVariant.ghost,
                          onTap: onSkip,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context, dynamic config) async {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    final urlStr = isIos ? config.appStoreUrlIos : config.appStoreUrlAndroid;

    if (urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Áruház link nincs beállítva.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
