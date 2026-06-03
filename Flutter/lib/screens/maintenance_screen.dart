import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../core/theme/app_theme.dart';
import '../core/components/components.dart';

// ============================================================
// MaintenanceScreen – Karbantartási képernyő  [M5]
//
// Az appból NEM lehet továbblépni amíg ez aktív.
// Az üzenet és cím a remote config-ból jön.
// Egy "Újrapróbálás" gombbal ellenőrzi le újra a konfig-ot.
// ============================================================

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, configState) {
        final title   = configState.config.maintenanceTitle;
        final message = configState.config.maintenanceMessage;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RadialBackground(
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ikon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.construction,
                          size: 48,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Cím
                      Text(
                        title,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.warning,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Üzenet
                      Text(
                        message,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onBackground.withValues(alpha: 0.7),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // Újrapróbálás gomb
                      AppButton(
                        label: 'Újrapróbálás',
                        icon: LucideIcons.refreshCw,
                        variant: AppButtonVariant.secondary,
                        isLoading: configState.isLoading,
                        onTap: configState.isLoading
                            ? null
                            : () => context.read<ConfigCubit>().load(),
                      ),

                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Ha a probléma tartósan fennáll, kérjük vedd fel a kapcsolatot az ügyfélszolgálattal.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onBackground.withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
