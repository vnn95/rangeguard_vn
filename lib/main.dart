import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rangeguard_vn/core/router/app_router.dart';
import 'package:rangeguard_vn/core/supabase/supabase_config.dart';
import 'package:rangeguard_vn/core/theme/app_theme.dart';
import 'package:rangeguard_vn/core/constants/app_constants.dart';
import 'package:rangeguard_vn/core/utils/offline_sync.dart';
import 'package:rangeguard_vn/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for offline storage
  await Hive.initFlutter();

  // Open all Hive boxes before the app starts so repositories
  // can access them synchronously via Hive.box()
  await Future.wait([
    Hive.openBox(AppConstants.patrolBox),
    Hive.openBox(AppConstants.waypointBox),
    Hive.openBox(AppConstants.scheduleBox),
    Hive.openBox(AppConstants.settingsBox),
    Hive.openBox(AppConstants.syncQueueBox),
  ]);

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize offline sync service
  await OfflineSyncService().init();

  runApp(
    const ProviderScope(
      child: RangerGuardApp(),
    ),
  );
}

class RangerGuardApp extends ConsumerWidget {
  const RangerGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'RangerGuard VN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
