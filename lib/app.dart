import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'pages/hosting/hosting_crud_page.dart';
import 'pages/hosting/hosting_feature_spec.dart';

class App extends StatelessWidget {
  // Static notifier to allow runtime theme changes from settings page
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  const App({super.key});

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
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.light,
              primary: const Color(0xFF0F766E),
              secondary: const Color(0xFFF59E0B),
            ),
            scaffoldBackgroundColor: const Color(0xFFF7FAFC),
            cardColor: Colors.white,
            textTheme: GoogleFonts.plusJakartaSansTextTheme(
              ThemeData.light().textTheme,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.black.withOpacity(0.8)),
              titleTextStyle: TextStyle(
                color: Colors.black.withOpacity(0.85),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Custom Premium Dark Theme
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.dark,
              primary: const Color(0xFF14B8A6),
              secondary: const Color(0xFFFBBF24),
            ),
            scaffoldBackgroundColor: const Color(0xFF08111F),
            cardColor: const Color(0xFF0F172A),
            textTheme: GoogleFonts.plusJakartaSansTextTheme(
              ThemeData.dark().textTheme,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF111827),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF0F172A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          initialRoute: isLoggedIn ? '/dashboard' : '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/dashboard': (context) => const DashboardPage(),
            '/hosting/nginx-config': (context) =>
                const HostingCrudPage(feature: HostingFeatures.nginxConfig),
            '/hosting/subdomain': (context) =>
                const HostingCrudPage(feature: HostingFeatures.subdomain),
            '/hosting/domain': (context) =>
                const HostingCrudPage(feature: HostingFeatures.domain),
            '/hosting/project': (context) =>
                const HostingCrudPage(feature: HostingFeatures.project),
            '/hosting/file-manager': (context) =>
                const HostingCrudPage(feature: HostingFeatures.fileManager),
            '/hosting/api-monitoring': (context) =>
                const HostingCrudPage(feature: HostingFeatures.apiMonitoring),
            '/hosting/other-services': (context) =>
                const HostingCrudPage(feature: HostingFeatures.otherServices),
            '/hosting/server': (context) =>
                const HostingCrudPage(feature: HostingFeatures.server),
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
