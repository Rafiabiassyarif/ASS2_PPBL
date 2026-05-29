import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../core/preferences/app_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _username = '';
  String _lastLogin = '';
  String _avatarPath = '';
  bool _isDarkMode = false;
  int _cardCount = 4;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final rawLogin = AppPreferences.getLastLoginTs();
    String formattedLogin = '-';
    if (rawLogin.isNotEmpty) {
      try {
        formattedLogin = DateFormat(
          'dd MMM yyyy, HH:mm',
        ).format(DateTime.parse(rawLogin));
      } catch (_) {}
    }

    setState(() {
      _username = AppPreferences.getAdminUsername();
      _lastLogin = formattedLogin;
      _avatarPath = AppPreferences.getAdminAvatar();
      _isDarkMode = AppPreferences.getThemeMode() == 'dark';
      _cardCount = AppPreferences.getDashboardCardCount();
    });
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (pickedFile != null) {
        await AppPreferences.setAdminAvatar(pickedFile.path);
        setState(() {
          _avatarPath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil gambar: $e')));
    }
  }

  void _toggleTheme(bool isDark) async {
    final themeStr = isDark ? 'dark' : 'light';
    await AppPreferences.setThemeMode(themeStr);

    // Update the App-level ThemeMode notifier
    App.themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _changeCardCount(int? value) async {
    if (value != null) {
      await AppPreferences.setDashboardCardCount(value);
      setState(() {
        _cardCount = value;
      });
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Aplikasi'),
        content: const Text('Apakah Anda yakin ingin keluar dari KolabPanel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppPreferences.clearSession();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Widget _buildAvatar() {
    if (!kIsWeb && _avatarPath.isNotEmpty) {
      try {
        final file = File(_avatarPath);
        if (file.existsSync()) {
          return CircleAvatar(radius: 50, backgroundImage: FileImage(file));
        }
      } catch (_) {}
    }
    return const CircleAvatar(
      radius: 50,
      backgroundColor: Colors.teal,
      child: Icon(Icons.admin_panel_settings, size: 54, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Admin Profile Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24.0,
                  horizontal: 16.0,
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildAvatar(),
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.teal,
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Administrator',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last login: $_lastLogin',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Settings Group: Tampilan
            _buildSectionTitle('Tampilan & Preferensi'),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _isDarkMode,
                    onChanged: _toggleTheme,
                    title: const Text('Mode Gelap (Dark Mode)'),
                    secondary: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.teal,
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view, color: Colors.teal),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Kartu Statistik Dashboard',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: DropdownButtonFormField<int>(
                            value: _cardCount,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: [1, 2, 3, 4].map((count) {
                              return DropdownMenuItem<int>(
                                value: count,
                                child: Text('$count'),
                              );
                            }).toList(),
                            onChanged: _changeCardCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Group: Akun & Sesi
            _buildSectionTitle('Sesi'),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                onTap: _logout,
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
              ),
            ),
            const SizedBox(height: 40),

            // Version info
            Text(
              'KolabPanel v1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Tugas Besar Flutter — Kelompok 4',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
          ),
        ),
      ),
    );
  }
}
