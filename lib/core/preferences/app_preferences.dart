import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String isLoggedIn = 'is_logged_in';
  static const String adminUsername = 'admin_username';
  static const String themeMode = 'theme_mode';
  static const String lastLoginTs = 'last_login_timestamp';
  static const String domainFilter = 'domain_filter_status';
  static const String showExpiredOnly = 'show_expired_only';
  static const String packageOrder = 'package_order';
  static const String dashboardCardCount = 'dashboard_card_count';
  static const String adminAvatar = 'admin_avatar';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Setters & Getters
  static String getAdminAvatar() {
    return _prefs?.getString(adminAvatar) ?? '';
  }

  static Future<void> setAdminAvatar(String value) async {
    await _prefs?.setString(adminAvatar, value);
  }

  static bool getIsLoggedIn() {
    return _prefs?.getBool(isLoggedIn) ?? false;
  }

  static Future<void> setIsLoggedIn(bool value) async {
    await _prefs?.setBool(isLoggedIn, value);
  }

  static String getAdminUsername() {
    return _prefs?.getString(adminUsername) ?? 'Admin';
  }

  static Future<void> setAdminUsername(String value) async {
    await _prefs?.setString(adminUsername, value);
  }

  static String getThemeMode() {
    return _prefs?.getString(themeMode) ?? 'light'; // 'light' or 'dark'
  }

  static Future<void> setThemeMode(String value) async {
    await _prefs?.setString(themeMode, value);
  }

  static String getLastLoginTs() {
    return _prefs?.getString(lastLoginTs) ?? '';
  }

  static Future<void> setLastLoginTs(String value) async {
    await _prefs?.setString(lastLoginTs, value);
  }

  static String getDomainFilter() {
    return _prefs?.getString(domainFilter) ?? 'Semua';
  }

  static Future<void> setDomainFilter(String value) async {
    await _prefs?.setString(domainFilter, value);
  }

  static bool getShowExpiredOnly() {
    return _prefs?.getBool(showExpiredOnly) ?? false;
  }

  static Future<void> setShowExpiredOnly(bool value) async {
    await _prefs?.setBool(showExpiredOnly, value);
  }

  static String getPackageOrder() {
    return _prefs?.getString(packageOrder) ?? '[]';
  }

  static Future<void> setPackageOrder(String value) async {
    await _prefs?.setString(packageOrder, value);
  }

  static int getDashboardCardCount() {
    return _prefs?.getInt(dashboardCardCount) ?? 4;
  }

  static Future<void> setDashboardCardCount(int value) async {
    await _prefs?.setInt(dashboardCardCount, value);
  }

  // Clear session on logout
  static Future<void> clearSession() async {
    await setIsLoggedIn(false);
    await _prefs?.remove(adminUsername);
  }
}
