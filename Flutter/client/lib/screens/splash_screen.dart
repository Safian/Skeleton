import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';

// ============================================================
// SplashScreen – induláskor látható töltőképernyő
// ============================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RadialBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo placeholder – cseréld le az alkalmazás logójára
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryVariant],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(Icons.rocket_launch_rounded,
                    size: 40, color: AppColors.onPrimary),
              ),
              const SizedBox(height: 24),
              Text('Skeleton App', style: AppTypography.titleLarge),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
