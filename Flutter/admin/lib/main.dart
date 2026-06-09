import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/translation_extension.dart';
import 'repositories/auth_repository.dart';
import 'repositories/admin_repository.dart';
import 'blocs/session/session_cubit.dart';
import 'blocs/session/session_state.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';

import 'repositories/translation_repository.dart';
import 'blocs/translation/translation_cubit.dart';
import 'blocs/admin/admin_cubit.dart';

// ============================================================
// Admin App – belépési pont
// Csak 'admin' role-lal rendelkező felhasználók használhatják.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl     = dotenv.env['SUPABASE_URL']     ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  assert(supabaseUrl.isNotEmpty,     'SUPABASE_URL hiányzik a .env fájlból!');
  assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY hiányzik a .env fájlból!');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  AppTheme.useDark();

  final authRepository  = AuthRepository();
  final adminRepository = AdminRepository();
  final translationRepository = TranslationRepository();

  runApp(AdminApp(
    authRepository:  authRepository,
    adminRepository: adminRepository,
    translationRepository: translationRepository,
  ));
}

class AdminApp extends StatelessWidget {
  final AuthRepository authRepository;
  final AdminRepository adminRepository;
  final TranslationRepository translationRepository;

  const AdminApp({
    super.key,
    required this.authRepository,
    required this.adminRepository,
    required this.translationRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: adminRepository),
        RepositoryProvider.value(value: translationRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SessionCubit(repository: authRepository)),
          BlocProvider(
            create: (_) => TranslationCubit(repository: translationRepository),
          ),
          BlocProvider(
            create: (_) => AdminCubit(repository: adminRepository),
          ),
        ],
        child: BlocBuilder<TranslationCubit, TranslationState>(
          builder: (context, translationState) {
            return MaterialApp(
              title: 'Skeleton Admin',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildMaterial(dark: true),
              home: const _AppRoot(),
            );
          },
        ),
      ),
    );
  }
}


class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        return switch (state) {
          SessionBooting()          => const SplashScreen(),
          SessionMaintenance()      => const _MaintenanceScreen(),
          SessionLoggedOut()        => const AuthScreen(),
          SessionPasswordRecovery() => const AuthScreen(showPasswordReset: true),
          SessionLoggedIn(profile: final p) when p.role != 'admin'
                                    => const _AccessDeniedScreen(),
          SessionLoggedIn()         => const HomeScreen(),
          _                         => const SplashScreen(),
        };
      },
    );
  }
}

// ── Maintenance ───────────────────────────────────────────────
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.build_rounded, size: 64, color: AppColors.warning),
          const SizedBox(height: 24),
          Text(context.t('maintenance.title', 'Karbantartás alatt'),
              style: AppTypography.titleLarge),
          const SizedBox(height: 12),
          Text(context.t('maintenance.body', 'Próbáld meg később.'),
              style: AppTypography.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Access denied ─────────────────────────────────────────────
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_outlined, size: 72, color: AppColors.error),
            const SizedBox(height: 24),
            Text(context.t('access_denied.title', 'Hozzáférés megtagadva'),
                style: AppTypography.titleLarge),
            const SizedBox(height: 12),
            Text(
              context.t('access_denied.body',
                  'Ez a felület kizárólag adminisztrátorok számára érhető el.'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onBackground.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(context.t('auth.logout', 'Kijelentkezés')),
              onPressed: () => context.read<SessionCubit>().signOut(),
            ),
          ]),
        ),
      ),
    );
  }
}
