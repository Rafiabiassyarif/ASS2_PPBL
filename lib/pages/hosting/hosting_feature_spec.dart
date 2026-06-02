import 'package:flutter/material.dart';

class HostingFeatureSpec {
  final String key;
  final String route;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String primaryLabel;
  final String primaryHint;
  final String secondaryLabel;
  final String secondaryHint;
  final String tertiaryLabel;
  final String tertiaryHint;
  final String descriptionLabel;
  final String descriptionHint;
  final List<String> statusOptions;
  final String defaultStatus;
  final bool showEnabledToggle;
  final bool descriptionMultiline;
  final int descriptionLines;

  const HostingFeatureSpec({
    required this.key,
    required this.route,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.primaryLabel,
    required this.primaryHint,
    required this.secondaryLabel,
    required this.secondaryHint,
    required this.tertiaryLabel,
    required this.tertiaryHint,
    required this.descriptionLabel,
    required this.descriptionHint,
    required this.statusOptions,
    required this.defaultStatus,
    required this.showEnabledToggle,
    required this.descriptionMultiline,
    required this.descriptionLines,
  });
}

class HostingFeatures {
  static const HostingFeatureSpec nginxConfig = HostingFeatureSpec(
    key: 'nginx_config',
    route: '/hosting/nginx-config',
    title: 'Nginx Config',
    subtitle: 'Kelola konfigurasi Nginx dan aktifkan saat siap digunakan',
    icon: Icons.webhook_rounded,
    accentColor: Color(0xFF0F766E),
    primaryLabel: 'Port',
    primaryHint: '80',
    secondaryLabel: 'Target Path',
    secondaryHint: '/var/www/app/public',
    tertiaryLabel: 'Project',
    tertiaryHint: 'Laravel / React / Node.js',
    descriptionLabel: 'Preview Config',
    descriptionHint: 'Config dibuat otomatis',
    statusOptions: ['available', 'enabled'],
    defaultStatus: 'available',
    showEnabledToggle: true,
    descriptionMultiline: true,
    descriptionLines: 5,
  );

  static const HostingFeatureSpec subdomain = HostingFeatureSpec(
    key: 'subdomain',
    route: '/hosting/subdomain',
    title: 'Subdomain',
    subtitle: 'Mapping subdomain tunnel ke hostname lokal',
    icon: Icons.device_hub_rounded,
    accentColor: Color(0xFF2563EB),
    primaryLabel: 'Subdomain',
    primaryHint: 'app',
    secondaryLabel: 'Domain',
    secondaryHint: 'example.com',
    tertiaryLabel: 'Service',
    tertiaryHint: 'localhost:80',
    descriptionLabel: 'Catatan',
    descriptionHint: 'Arahkan subdomain ke host internal',
    statusOptions: ['active', 'pending', 'paused'],
    defaultStatus: 'active',
    showEnabledToggle: true,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const HostingFeatureSpec domain = HostingFeatureSpec(
    key: 'domain',
    route: '/hosting/domain',
    title: 'Domain',
    subtitle: 'Kelola domain utama dan nameserver untuk routing layanan',
    icon: Icons.public_rounded,
    accentColor: Color(0xFFF59E0B),
    primaryLabel: 'Nameserver 1',
    primaryHint: 'ada.ns.cloudflare.com',
    secondaryLabel: 'Nameserver 2',
    secondaryHint: 'nina.ns.cloudflare.com',
    tertiaryLabel: 'Registrar',
    tertiaryHint: 'Cloudflare',
    descriptionLabel: 'Catatan',
    descriptionHint: 'Tambahkan kebutuhan verifikasi domain',
    statusOptions: ['pending', 'verified', 'expired'],
    defaultStatus: 'pending',
    showEnabledToggle: false,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const HostingFeatureSpec project = HostingFeatureSpec(
    key: 'project',
    route: '/hosting/project',
    title: 'Project',
    subtitle: 'Kelola project, domain aktif, repository, dan stack deployment',
    icon: Icons.dashboard_customize_rounded,
    accentColor: Color(0xFF1D4ED8),
    primaryLabel: 'Domain',
    primaryHint: 'project.example.com',
    secondaryLabel: 'Repository',
    secondaryHint: 'https://github.com/your-repo',
    tertiaryLabel: 'Stack',
    tertiaryHint: 'Flutter / Laravel / Node',
    descriptionLabel: 'Catatan',
    descriptionHint: 'Jelaskan progres, sprint, atau target deploy',
    statusOptions: ['planning', 'review', 'deployed'],
    defaultStatus: 'planning',
    showEnabledToggle: false,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const HostingFeatureSpec fileManager = HostingFeatureSpec(
    key: 'file_manager',
    route: '/hosting/file-manager',
    title: 'File Manager',
    subtitle: 'Kelola file, folder, dan permission',
    icon: Icons.folder_copy_rounded,
    accentColor: Color(0xFFEA580C),
    primaryLabel: 'Path',
    primaryHint: '/var/www/app/public',
    secondaryLabel: 'Type',
    secondaryHint: 'file / folder',
    tertiaryLabel: 'Permission',
    tertiaryHint: '755 / 644',
    descriptionLabel: 'Catatan',
    descriptionHint: 'Tambahkan ukuran, kepemilikan, atau versi',
    statusOptions: ['ready', 'syncing', 'archived'],
    defaultStatus: 'ready',
    showEnabledToggle: false,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const HostingFeatureSpec apiMonitoring = HostingFeatureSpec(
    key: 'api_monitoring',
    route: '/hosting/api-monitoring',
    title: 'API Monitoring',
    subtitle: 'Polling URL API setiap beberapa detik',
    icon: Icons.monitor_heart_rounded,
    accentColor: Color(0xFF14B8A6),
    primaryLabel: 'API URL',
    primaryHint: 'https://api.example.com/health',
    secondaryLabel: 'Interval (detik)',
    secondaryHint: '5',
    tertiaryLabel: 'Expected Code',
    tertiaryHint: '200',
    descriptionLabel: 'Catatan',
    descriptionHint: 'Simpan info alert, token, atau respons penting',
    statusOptions: ['healthy', 'degraded', 'down'],
    defaultStatus: 'healthy',
    showEnabledToggle: true,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const HostingFeatureSpec otherServices = HostingFeatureSpec(
    key: 'other_services',
    route: '/hosting/other-services',
    title: 'Backup Database',
    subtitle: 'Konfigurasi backup database dan koneksi port',
    icon: Icons.backup_rounded,
    accentColor: Color(0xFF0EA5E9),
    primaryLabel: 'Host / Database',
    primaryHint: 'localhost/app_db',
    secondaryLabel: 'Jenis Database',
    secondaryHint: 'MySQL',
    tertiaryLabel: 'Port',
    tertiaryHint: '3306',
    descriptionLabel: 'Catatan Backup',
    descriptionHint: 'Jadwal backup, lokasi dump, atau kredensial aman',
    statusOptions: ['ready', 'running', 'success', 'failed'],
    defaultStatus: 'ready',
    showEnabledToggle: false,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const HostingFeatureSpec server = HostingFeatureSpec(
    key: 'server',
    route: '/hosting/server',
    title: 'Server',
    subtitle: 'Pantau node server dan status uptime',
    icon: Icons.storage_rounded,
    accentColor: Color(0xFF059669),
    primaryLabel: 'IP Address',
    primaryHint: '192.168.1.10',
    secondaryLabel: 'Username SSH',
    secondaryHint: 'root',
    tertiaryLabel: 'SSH Port',
    tertiaryHint: '22',
    descriptionLabel: 'Catatan',
    descriptionHint: 'Tambahkan lokasi, provider, atau spesifikasi',
    statusOptions: ['online', 'offline', 'maintenance'],
    defaultStatus: 'online',
    showEnabledToggle: false,
    descriptionMultiline: true,
    descriptionLines: 4,
  );

  static const List<HostingFeatureSpec> all = [
    nginxConfig,
    subdomain,
    domain,
    project,
    fileManager,
    apiMonitoring,
    otherServices,
    server,
  ];
}
