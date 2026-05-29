import 'package:flutter/material.dart';
import 'core/preferences/app_preferences.dart';
import 'pages/login/login_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/domains/domain_list_page.dart';
import 'pages/domains/domain_add_page.dart';
import 'pages/domains/domain_edit_page.dart';
import 'pages/users/user_list_page.dart';
import 'pages/users/user_add_page.dart';
import 'pages/users/user_edit_page.dart';
import 'pages/packages/package_list_page.dart';
import 'pages/packages/package_add_page.dart';
import 'pages/packages/package_edit_page.dart';
import 'pages/tickets/ticket_list_page.dart';
import 'pages/tickets/ticket_add_page.dart';
import 'pages/tickets/ticket_detail_page.dart';
import 'pages/settings/settings_page.dart';

class App extends StatelessWidget {
  // Static notifier to allow runtime theme changes from settings page
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize the notifier value based on saved preference
    final savedTheme = AppPreferences.getThemeMode();
    themeNotifier.value = savedTheme == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;

    // Check login state to determine the initial route
    final bool isLoggedIn = AppPreferences.getIsLoggedIn();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'KolabPanel',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Custom Premium Light Theme
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
              primary: Colors.teal,
              secondary: Colors.tealAccent.shade700,
            ),
            scaffoldBackgroundColor: Colors.grey.shade50,
            cardColor: Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.black.withOpacity(0.8)),
              titleTextStyle: TextStyle(
                color: Colors.black.withOpacity(0.85),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Custom Premium Dark Theme
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
              primary: Colors.teal.shade400,
              secondary: Colors.tealAccent,
            ),
            scaffoldBackgroundColor: Colors.grey.shade900,
            cardColor: Colors.grey.shade900,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          initialRoute: isLoggedIn ? '/dashboard' : '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/dashboard': (context) => const DashboardPage(),
            // Domain routes
            '/domains': (context) => const DomainListPage(),
            '/domains/add': (context) => const DomainAddPage(),
            '/domains/edit': (context) => const DomainEditPage(),
            // User routes
            '/users': (context) => const UserListPage(),
            '/users/add': (context) => const UserAddPage(),
            '/users/edit': (context) => const UserEditPage(),
            // Package routes
            '/packages': (context) => const PackageListPage(),
            '/packages/add': (context) => const PackageAddPage(),
            '/packages/edit': (context) => const PackageEditPage(),
            // Ticket routes
            '/tickets': (context) => const TicketListPage(),
            '/tickets/add': (context) => const TicketAddPage(),
            '/tickets/detail': (context) => const TicketDetailPage(),
            // Settings route
            '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}
