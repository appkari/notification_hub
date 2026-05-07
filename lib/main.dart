import 'package:flutter/material.dart'
    show
        BuildContext,
        ColorScheme,
        Colors,
        MaterialApp,
        Brightness,
        CardThemeData,
        AppBarTheme,
        BorderRadius,
        StatelessWidget,
        RoundedRectangleBorder,
        SnackBarBehavior,
        SnackBarThemeData,
        ThemeData,
        Widget,
        WidgetsFlutterBinding,
        Color,
        debugPrint,
        runApp,
        Builder;
// runApp is a top-level function and doesn't need to be shown explicitly.
import 'package:provider/provider.dart'
    show ChangeNotifierProvider, MultiProvider, Provider;
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:notification_listener_service/notification_listener_service.dart'
    show NotificationListenerService;

import 'providers/notification_provider.dart' show NotificationProvider;
import 'providers/subscription_provider.dart' show SubscriptionProvider;
import 'screens/home_screen.dart' show HomeScreen;
import 'screens/settings_screen.dart' show SettingsScreen;
import 'screens/dashboard_screen.dart' show DashboardScreen;
import 'screens/app_management_screen.dart' show AppManagementScreen;
import 'screens/subscription_screen.dart' show SubscriptionScreen;
import 'providers/theme_provider.dart';
import 'flavors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notification listener service
  try {
    // Check if permission is granted
    final hasPermission =
        await NotificationListenerService.isPermissionGranted();
    if (!hasPermission) {
      // This will be handled in the NotificationService class
      // but we pre-check here to ensure early initialization
    }
  } catch (e) {
    debugPrint('Error initializing notification listener service: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider()..initialize(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final lightScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A5F),
            brightness: Brightness.light,
          );
          final darkScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF7DD3FC),
            brightness: Brightness.dark,
          );
          return MaterialApp(
            title: FlavorConfig.title,
            theme: ThemeData(
              colorScheme: lightScheme,
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF4F7FB),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFFF4F7FB),
                foregroundColor: lightScheme.onSurface,
                elevation: 0,
                centerTitle: false,
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: darkScheme,
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF07111F),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: const Color(0xFF07111F),
                foregroundColor: darkScheme.onSurface,
                elevation: 0,
                centerTitle: false,
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const HomeScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/apps': (context) => const AppManagementScreen(),
              '/subscription': (context) => const SubscriptionScreen(),
            },
          );
        },
      ),
    );
  }
}
