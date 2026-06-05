import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_localizations/flutter_localizations.dart'; // [M4.2]
import 'core/theme/app_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/items_repository.dart';
import 'blocs/session/session_cubit.dart';
import 'blocs/session/session_state.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';

import 'repositories/translation_repository.dart';
import 'blocs/translation/translation_cubit.dart';
import 'screens/auth/invite_accept_screen.dart';
import 'services/deep_link_service.dart';
import 'widgets/qa_shield/qa_shield_overlay.dart'; // [M4.1]
import 'screens/update_screens.dart';           // [M3.1]
import 'services/push_notification_service.dart';

// ============================================================
// main.dart – belépési pont
//
// ENV változók: .env fájlból (flutter_dotenv)
//   SUPABASE_URL=...
//   SUPABASE_ANON_KEY=...
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env betöltése
  await dotenv.load(fileName: '.env');

  final supabaseUrl     = dotenv.env['SUPABASE_URL']     ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  assert(supabaseUrl.isNotEmpty,
      'SUPABASE_URL hiányzik a .env fájlból!');
  assert(supabaseAnonKey.isNotEmpty,
      'SUPABASE_ANON_KEY hiányzik a .env fájlból!');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  await PushNotificationService.instance.initialize();

  AppTheme.useDark();

  final authRepository  = AuthRepository();
  final itemsRepository = ItemsRepository();
  final translationRepository = TranslationRepository();

  runApp(SkeletonApp(
    authRepository:  authRepository,
    itemsRepository: itemsRepository,
    translationRepository: translationRepository,
  ));
}

// ============================================================
// SkeletonApp – root widget
// ============================================================

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

class SkeletonApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ItemsRepository itemsRepository;
  final TranslationRepository translationRepository;

  const SkeletonApp({
    super.key,
    required this.authRepository,
    required this.itemsRepository,
    required this.translationRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: itemsRepository),
        RepositoryProvider.value(value: translationRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SessionCubit(repository: authRepository)),
          BlocProvider(
            create: (_) => TranslationCubit(repository: translationRepository)
              ..loadTranslations('hu'),
          ),
        ],
        child: BlocBuilder<TranslationCubit, TranslationState>(
          builder: (context, translationState) {
            return MaterialApp(
              title: 'Skeleton App',
              // [M4.2] Localization delegates
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('hu'),
                Locale('en'),
                Locale('de'),
              ],
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildMaterial(dark: true),
              navigatorKey: _navKey,
              onGenerateRoute: _generateRoute,
              home: const _DeepLinkInit(child: QaShieldOverlay(child: AppRoot())),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// AppRoot – routing az állapotgép alapján
// ============================================================

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionCubit, SessionState>(
      listener: (context, state) {
        if (state is SessionLoggedIn) {
          context.read<TranslationCubit>().loadTranslations(state.profile.language);
        }
      },
      child: BlocBuilder<SessionCubit, SessionState>(
        builder: (context, state) {
          return switch (state) {
            SessionBooting()       => const SplashScreen(),
            SessionMaintenance(:final title, :final message) => _MaintenanceScreen(
                title:   title,
                message: message,
              ),
            SessionForceUpdate(:final currentVersion, :final requiredVersion, :final storeUrl) => ForceUpdateScreen(
                currentVersion:  currentVersion,
                requiredVersion: requiredVersion,
                storeUrl:        storeUrl,
              ),
            SessionSoftUpdate(:final currentVersion, :final latestVersion, :final storeUrl) => SoftUpdateScreen(
                currentVersion: currentVersion,
                latestVersion:  latestVersion,
                storeUrl:       storeUrl,
              ),
            SessionLoggedOut()     => const AuthScreen(),
            SessionLoggedIn()      => const HomeScreen(),
            SessionPasswordRecovery() => const AuthScreen(showPasswordReset: true),
            _ => const SplashScreen(),
          };
        },
      ),
    );
  }
}


Route<dynamic>? _generateRoute(RouteSettings settings) {
  if (settings.name == '/invite-accept') {
    final token = settings.arguments as String? ?? '';
    if (token.isNotEmpty) {
      return MaterialPageRoute(
        builder: (_) => InviteAcceptScreen(token: token),
        settings: settings,
      );
    }
  }
  return null;
}

class _DeepLinkInit extends StatefulWidget {
  final Widget child;
  const _DeepLinkInit({required this.child});
  @override
  State<_DeepLinkInit> createState() => _DeepLinkInitState();
}

class _DeepLinkInitState extends State<_DeepLinkInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.initialize(_navKey);
    });
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Maintenance képernyő ──────────────────────────────────────
class _MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;
  const _MaintenanceScreen({
    this.title   = 'Karbantartás alatt',
    this.message = 'Az alkalmazás jelenleg karbantartás alatt van. Kérjük, próbáld meg később.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_rounded, size: 64,
                  color: AppColors.warning),
              const SizedBox(height: 24),
              Text(title, style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty
                    ? message
                    : 'Az alkalmazás jelenleg karbantartás alatt van. Kérjük, próbáld meg később.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.onBackground.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
