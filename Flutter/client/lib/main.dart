import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_localizations/flutter_localizations.dart'; // [M4.2]
import 'repositories/auth_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/translation_repository.dart';
import 'blocs/session/session_cubit.dart';
import 'blocs/session/session_state.dart';
import 'blocs/config/config_cubit.dart';                // [M5]
import 'blocs/config/config_state.dart';                // [M5]
import 'blocs/translation/translation_cubit.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/invite_accept_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/maintenance_screen.dart';               // [M5]
import 'screens/update_required_screen.dart';           // [M5]
import 'screens/legal_accept_screen.dart';
import 'services/deep_link_handler.dart';
import 'services/push_notification_service.dart';
import 'widgets/qa_shield/qa_shield_overlay.dart';      // [M4.1]

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

  // Clear corrupt Supabase localStorage keys on web (no-op on native)
  clearSupabaseLocalStorage();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Init centralised error logger
  LogService.instance.init(Supabase.instance.client);

  await PushNotificationService.instance.initialize();

  AppTheme.useDark();

  runApp(SkeletonApp(
    authRepository:        AuthRepository(),
    itemsRepository:       ItemsRepository(),
    translationRepository: TranslationRepository(),
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
          // [M5] Remote Config – legkorábban inicializálódik
          BlocProvider(
            create: (_) => ConfigCubit()..load(),
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
              home: const _DeepLinkInit(
                child: QaShieldOverlay(
                  child: ForegroundPushOverlay(
                    child: AppRoot(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// AppRoot – routing prioritásrendben
//
// 1. Config (maintenance / force / soft update)  [M5]
// 2. Auth (logged in / out / password recovery)
//
// A ConfigCubit és SessionCubit párhuzamosan tölt –
// amíg a config még nincs kész, a session SplashScreen-t mutat.
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
      // Amikor a config betöltési állapota megváltozik, reset a skip flagre
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, configState) {
        if (!RemoteConfig.instance.maintenanceMode) {
          setState(() => _softUpdateSkipped = false);
        }
      },
      builder: (context, configState) {
        // ── 1. Maintenance mode ─────────────────────────────
        if (configState.isLoaded && RemoteConfig.instance.maintenanceMode) {
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
              context
                  .read<TranslationCubit>()
                  .loadTranslations(sessionState.profile.language);
            }
            // Force-logout message
            if (sessionState is SessionLoggedOut &&
                sessionState.message != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(sessionState.message!),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 5),
                  ),
                );
              });
            }
          },
          builder: (context, sessionState) {
            return switch (sessionState) {
              SessionBooting()          => const SplashScreen(),
              SessionLoggedOut()        => const AuthScreen(),
              SessionLoggedIn()         => const HomeScreen(),
              SessionPasswordRecovery() => const AuthScreen(showPasswordReset: true),
              SessionMaintenance()      => const MaintenanceScreen(),
              SessionAcceptLegal()      => LegalAcceptScreen(
                                            state: sessionState,
                                          ),
              _                         => const SplashScreen(),
            };
          },
        );
      },
    );
  }
}

// ── Named route generator ──────────────────────────────────────

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

// ── Deep link init + routing ───────────────────────────────────

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
      DeepLinkHandler.instance
        ..onLink = _routeDeepLink
        ..init();
    });
  }

  @override
  void dispose() {
    DeepLinkHandler.instance.dispose();
    super.dispose();
  }

  void _routeDeepLink(DeepLinkMatch match) {
    if (!mounted) return;
    debugPrint('[DeepLink] routing action=${match.action} params=${match.params}');

    switch (match.action) {
      case 'invite':
        final token = match.params['token'] ?? '';
        if (token.isNotEmpty) {
          _navKey.currentState?.pushNamed('/invite-accept', arguments: token);
        }

      case 'reset_password':
        // Supabase handles this via SessionPasswordRecovery state — no extra nav needed.
        break;

      case 'resolve_token':
        // Token-based deep link: resolve JWT → {action, target, userId?} via edge function.
        final token = match.params['token'];
        if (token != null && token.isNotEmpty) {
          _resolveDeeplinkToken(token);
        }

      default:
        debugPrint('[DeepLink] unhandled action: ${match.action}');
    }
  }

  /// Calls the resolve-deeplink edge function to verify the JWT token and
  /// extract {action, target, userId?}, then dispatches the resulting match.
  /// Fire-and-forget — errors are logged and silently ignored.
  Future<void> _resolveDeeplinkToken(String token) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'resolve-deeplink',
        body: {'token': token},
      );
      final data = response.data;
      if (data == null || data is! Map) {
        debugPrint('[DeepLink] resolve_token: empty or unexpected response');
        return;
      }
      final action = data['action'] as String?;
      final target = data['target'] as String?;
      final userId = data['userId'] as String?;
      if (action == null || target == null) {
        debugPrint('[DeepLink] resolve_token: missing fields in response');
        return;
      }
      debugPrint('[DeepLink] resolve_token → action=$action target=$target userId=$userId');
      // Dispatch as a new match so app-level switch handles it uniformly.
      _routeDeepLink(DeepLinkMatch(
        action: action,
        params: {'target': target, if (userId != null) 'userId': userId},
        uri: Uri.parse('app://resolved/$action/$target'),
      ));
    } catch (e) {
      debugPrint('[DeepLink] resolve_token error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
