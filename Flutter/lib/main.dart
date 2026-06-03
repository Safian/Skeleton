import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/config_repository.dart';
import 'repositories/translation_repository.dart';
import 'blocs/session/session_cubit.dart';
import 'blocs/session/session_state.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/config/config_state.dart';
import 'blocs/translation/translation_cubit.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/invite_accept_screen.dart'; // [M2]
import 'screens/maintenance_screen.dart';
import 'screens/update_required_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/bug_reporter.dart'; // [M7]

// ============================================================
// main.dart – belépési pont
//
// ENV változók: .env fájlból (flutter_dotenv)
//   SUPABASE_URL=...
//   SUPABASE_ANON_KEY=...
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

  runApp(SkeletonApp(
    authRepository:        AuthRepository(),
    itemsRepository:       ItemsRepository(),
    configRepository:      ConfigRepository(),
    translationRepository: TranslationRepository(),
  ));
}

// ============================================================
// SkeletonApp – root widget
// ============================================================

// [M7] Stabil kulcs a bug-reporter screenshot RepaintBoundary-jához.
// Top-level final, hogy ne generálódjon újra minden buildnél.
final GlobalKey _bugRepaintKey = GlobalKey();

class SkeletonApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ItemsRepository itemsRepository;
  final ConfigRepository configRepository;
  final TranslationRepository translationRepository;

  const SkeletonApp({
    super.key,
    required this.authRepository,
    required this.itemsRepository,
    required this.configRepository,
    required this.translationRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: itemsRepository),
        RepositoryProvider.value(value: configRepository),
        RepositoryProvider.value(value: translationRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          // Remote Config – legkorábban inicializálódik
          BlocProvider(
            create: (_) => ConfigCubit(repository: configRepository)..load(),
          ),
          BlocProvider(
            create: (_) => SessionCubit(repository: authRepository),
          ),
          BlocProvider(
            create: (_) => TranslationCubit(repository: translationRepository)
              ..loadTranslations('hu'),
          ),
        ],
        child: BlocBuilder<TranslationCubit, TranslationState>(
          builder: (context, _) {
            return MaterialApp(
              title: 'Skeleton App',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildMaterial(dark: true),

              // ── Deep link / named route kezelés ──────────────
              // Invite-accept: /invite-accept?token=<uuid>
              // OAuth callback: supabase_flutter kezeli automatikusan
              onGenerateRoute: _generateRoute,

              // [M7] QA Bug Reporter – csak debug/staging buildben aktív
              // 3 ujjas tripla tap → screenshot + annotáció + beküldés.
              // A RepaintBoundary + stabil GlobalKey kell a screenshothoz.
              builder: kDebugMode
                  ? (context, child) => BugReporterGestureDetector(
                        repaintKey: _bugRepaintKey,
                        child: RepaintBoundary(
                          key: _bugRepaintKey,
                          child: child!,
                        ),
                      )
                  : null,

              home: const AppRoot(),
            );
          },
        ),
      ),
    );
  }

  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri == null) return null;

    // /invite-accept?token=<uuid>
    if (uri.path == '/invite-accept') {
      final token = uri.queryParameters['token'] ?? '';
      if (token.isNotEmpty) {
        return MaterialPageRoute(
          builder: (_) => InviteAcceptScreen(token: token),
          settings: settings,
        );
      }
    }

    return null;
  }
}

// ============================================================
// AppRoot – routing az állapotgép alapján
// Prioritás: Config (maintenance/update) → Session (auth)
// ============================================================

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  /// Soft update esetén a felhasználó elutasíthatja – ilyenkor true
  bool _softUpdateSkipped = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConfigCubit, ConfigState>(
      listenWhen: (prev, curr) =>
          prev.config.maintenanceMode != curr.config.maintenanceMode,
      listener: (context, configState) {
        // Ha a maintenance mód megváltozik, reset-eljük a skip flaget
        if (!configState.maintenanceOn) _softUpdateSkipped = false;
      },
      builder: (context, configState) {
        // ── 1. Maintenance mode ─────────────────────────────
        if (configState.isLoaded && configState.maintenanceOn) {
          return const MaintenanceScreen();
        }

        // ── 2. Force update ─────────────────────────────────
        if (configState.isLoaded && configState.forceUpdate) {
          return const UpdateRequiredScreen(isForce: true);
        }

        // ── 3. Soft update (ha nem utasítottuk el) ──────────
        if (configState.isLoaded &&
            configState.softUpdate &&
            !_softUpdateSkipped) {
          return UpdateRequiredScreen(
            isForce: false,
            onSkip: () => setState(() => _softUpdateSkipped = true),
          );
        }

        // ── 4. Auth routing ─────────────────────────────────
        return BlocConsumer<SessionCubit, SessionState>(
          listener: (context, sessionState) {
            if (sessionState is SessionLoggedIn) {
              // Nyelv betöltése a felhasználó preferenciája alapján
              context
                  .read<TranslationCubit>()
                  .loadTranslations(sessionState.profile.language);
            }
          },
          builder: (context, sessionState) {
            return switch (sessionState) {
              SessionBooting()          => const SplashScreen(),
              // Maintenance mód a config cubit-ből jön – ez már fentebb kezelt
              SessionMaintenance()      => const MaintenanceScreen(),
              SessionLoggedOut()        => const AuthScreen(),
              SessionLoggedIn()         => const HomeScreen(),
              SessionPasswordRecovery() => const AuthScreen(showPasswordReset: true),
              _                         => const SplashScreen(),
            };
          },
        );
      },
    );
  }
}
