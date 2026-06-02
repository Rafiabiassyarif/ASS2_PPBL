import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:http/http.dart' as http;
import '../../core/database/database_helper.dart';
import '../../models/hosting_record_model.dart';
import 'hosting_feature_spec.dart';
import 'hosting_record_form_page.dart';

enum _NginxViewMode { available, enabled }

class HostingCrudPage extends StatefulWidget {
  final HostingFeatureSpec feature;

  const HostingCrudPage({super.key, required this.feature});

  @override
  State<HostingCrudPage> createState() => _HostingCrudPageState();
}

class _HostingCrudPageState extends State<HostingCrudPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<HostingRecord> _records = [];
  List<String>? _fileManagerProjects;
  final Set<int> _testingApiRecordIds = {};
  final Set<int> _runningApiRecordIds = {};
  final Set<int> _runningBackupRecordIds = {};
  final Set<int> _testingServerRecordIds = {};
  final Map<int, Timer> _apiMonitoringTimers = {};
  final Map<int, int> _apiLatencyMsById = {};
  final Map<int, DateTime> _apiLastCheckedById = {};
  final Map<int, int> _serverLatencyMsById = {};
  final Map<int, DateTime> _serverLastCheckedById = {};
  HostingRecord? _fileManagerClipboardRecord;
  String? _fileManagerClipboardAction;
  String _selectedFileManagerProject = 'Semua';
  String _fileManagerPath = '/';
  bool _isLoading = true;
  _NginxViewMode _nginxViewMode = _NginxViewMode.available;

  HostingFeatureSpec get _feature => widget.feature;
  bool get _isNginxConfig => _feature.key == 'nginx_config';
  bool get _isSubdomainConfig => _feature.key == 'subdomain';
  bool get _isDomainConfig => _feature.key == 'domain';
  bool get _isFileManagerConfig => _feature.key == 'file_manager';
  bool get _isApiMonitoringConfig => _feature.key == 'api_monitoring';
  bool get _isBackupDatabaseConfig => _feature.key == 'other_services';
  bool get _isServerConfig => _feature.key == 'server';

  List<HostingRecord> get _nginxEnabledRecords => _records
      .where((record) => record.status.toLowerCase() == 'enabled')
      .toList();

  List<HostingRecord> get _nginxWarehouseRecords => _records;

  List<HostingRecord> get _nginxVisibleRecords =>
      _nginxViewMode == _NginxViewMode.enabled
      ? _nginxEnabledRecords
      : _nginxWarehouseRecords;

  List<HostingRecord> get _fileManagerVisibleRecords {
    if (!_isFileManagerConfig) return _records;

    final projectRecords = _selectedFileManagerProject == 'Semua'
        ? _records
        : _records
              .where(
                (record) => record.tertiaryValue == _selectedFileManagerProject,
              )
              .toList();

    return projectRecords
        .where((record) => _parentPath(record.primaryValue) == _fileManagerPath)
        .toList()
      ..sort((a, b) {
        final aFile = a.secondaryValue.toLowerCase() == 'file';
        final bFile = b.secondaryValue.toLowerCase() == 'file';
        if (aFile != bFile) return aFile ? 1 : -1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  }

  List<String> get _safeFileManagerProjects => _fileManagerProjects ?? const [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    for (final timer in _apiMonitoringTimers.values) {
      timer.cancel();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _dbHelper.getHostingRecords(
        _feature.key,
        query: _searchController.text.trim(),
      );
      var fileManagerProjects = _safeFileManagerProjects;
      var selectedProject = _selectedFileManagerProject;

      if (_isFileManagerConfig) {
        final projects = await _dbHelper.getHostingRecords(
          HostingFeatures.project.key,
        );
        fileManagerProjects =
            projects
                .map((record) => record.title.trim())
                .where((project) => project.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        if (selectedProject != 'Semua' &&
            !fileManagerProjects.contains(selectedProject)) {
          selectedProject = 'Semua';
        }
      }

      setState(() {
        _records = records;
        _fileManagerProjects = fileManagerProjects;
        _selectedFileManagerProject = selectedProject;
        if (_isFileManagerConfig && !_hasCurrentFileManagerPath(records)) {
          _fileManagerPath = '/';
        }
        _isLoading = false;
      });
      _syncApiMonitoringTimers(records);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat ${_feature.title.toLowerCase()}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openForm({HostingRecord? record}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HostingRecordFormPage(feature: _feature, record: record),
      ),
    );

    if (result == true) {
      _loadRecords();
    }
  }

  Future<void> _deleteRecord(HostingRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${_feature.title}'),
        content: Text('Data "${record.title}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && record.id != null) {
      try {
        await _dbHelper.deleteHostingRecord(record.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_feature.title} berhasil dihapus'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _loadRecords();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus ${_feature.title.toLowerCase()}: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _toggleEnabled(HostingRecord record) async {
    if (record.id == null) {
      return;
    }

    try {
      await _dbHelper.updateHostingRecord(
        record.copyWith(
          isEnabled: !record.isEnabled,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _syncApiMonitoringTimers(List<HostingRecord> records) {
    if (!_isApiMonitoringConfig) return;

    for (final timer in _apiMonitoringTimers.values) {
      timer.cancel();
    }
    _apiMonitoringTimers.clear();

    for (final record in records) {
      final id = record.id;
      if (id == null || !record.isEnabled) continue;

      final interval = _apiIntervalSeconds(record);
      _apiMonitoringTimers[id] = Timer.periodic(
        Duration(seconds: interval),
        (_) => _runApiCheck(record, manual: false),
      );
    }
  }

  int _apiIntervalSeconds(HostingRecord record) {
    final interval = int.tryParse(record.secondaryValue.trim()) ?? 5;
    if (interval < 3) return 3;
    return interval;
  }

  Future<void> _testApiEndpoint(HostingRecord record) {
    return _runApiCheck(record, manual: true);
  }

  Future<void> _runApiCheck(
    HostingRecord record, {
    required bool manual,
  }) async {
    final id = record.id;
    final url = record.primaryValue.trim();
    final uri = Uri.tryParse(url);

    if (id == null || uri == null || !uri.hasScheme || !uri.hasAuthority) {
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL API tidak valid'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (_runningApiRecordIds.contains(id)) {
      if (manual) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Test masih berjalan')));
      }
      return;
    }

    setState(() {
      _runningApiRecordIds.add(id);
      if (manual) {
        _testingApiRecordIds.add(id);
      }
    });

    final expectedCode = int.tryParse(record.tertiaryValue.trim()) ?? 200;
    var nextStatus = 'down';
    var message = 'API tidak bisa diakses';
    final now = DateTime.now().toIso8601String();
    final checkedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    try {
      final statusCode = await _fetchApiStatusCode(uri);
      stopwatch.stop();

      if (statusCode == expectedCode) {
        nextStatus = 'healthy';
        message =
            'API berjalan normal ($statusCode, ${stopwatch.elapsedMilliseconds} ms)';
      } else {
        nextStatus = 'degraded';
        message =
            'API merespons $statusCode, expected $expectedCode (${stopwatch.elapsedMilliseconds} ms)';
      }

      await _dbHelper.updateHostingRecord(
        record.copyWith(status: nextStatus, updatedAt: now),
      );
    } catch (e) {
      stopwatch.stop();
      message = 'API tidak berjalan: $e';
      try {
        await _dbHelper.updateHostingRecord(
          record.copyWith(status: 'down', updatedAt: now),
        );
      } catch (_) {
        message = 'API tidak berjalan dan status gagal diperbarui';
      }
    } finally {
      if (mounted) {
        setState(() {
          _runningApiRecordIds.remove(id);
          _testingApiRecordIds.remove(id);
          _apiLatencyMsById[id] = stopwatch.elapsedMilliseconds;
          _apiLastCheckedById[id] = checkedAt;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _records = _records
          .map(
            (item) => item.id == id
                ? item.copyWith(status: nextStatus, updatedAt: now)
                : item,
          )
          .toList();
    });

    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: nextStatus == 'healthy'
              ? Colors.green.shade600
              : nextStatus == 'degraded'
              ? Colors.orange.shade700
              : Colors.redAccent,
        ),
      );
    }
  }

  Future<int> _fetchApiStatusCode(Uri uri) async {
    final client = http.Client();

    try {
      final response = await client
          .get(uri, headers: const {'Accept': '*/*'})
          .timeout(const Duration(seconds: 6));
      return response.statusCode;
    } finally {
      client.close();
    }
  }

  Future<void> _testServerStatus(HostingRecord record) async {
    final id = record.id;
    final endpoint = _serverEndpoint(record);
    final settings = _serverSettingsFromDescription(record.description);
    final username = record.secondaryValue.trim();
    final password = settings['password'] ?? '';

    if (id == null || endpoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host atau port server tidak valid'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (username.isEmpty || username == '-' || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username atau password SSH belum diisi'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_testingServerRecordIds.contains(id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test masih berjalan')));
      return;
    }

    setState(() => _testingServerRecordIds.add(id));

    var nextStatus = 'offline';
    var message = 'Server tidak bisa diakses';
    final now = DateTime.now().toIso8601String();
    final checkedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    try {
      await _testSshConnection(
        host: endpoint.host,
        port: endpoint.port,
        username: username,
        password: password,
      );
      stopwatch.stop();

      nextStatus = 'online';
      message = 'SSH online (${stopwatch.elapsedMilliseconds} ms)';

      await _dbHelper.updateHostingRecord(
        record.copyWith(status: nextStatus, updatedAt: now),
      );
    } catch (e) {
      stopwatch.stop();
      message = 'SSH offline: ${_serverTestErrorMessage(e)}';
      try {
        await _dbHelper.updateHostingRecord(
          record.copyWith(status: 'offline', updatedAt: now),
        );
      } catch (_) {
        message = 'Server offline dan status gagal diperbarui';
      }
    } finally {
      if (mounted) {
        setState(() {
          _testingServerRecordIds.remove(id);
          _serverLatencyMsById[id] = stopwatch.elapsedMilliseconds;
          _serverLastCheckedById[id] = checkedAt;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _records = _records
          .map(
            (item) => item.id == id
                ? item.copyWith(status: nextStatus, updatedAt: now)
                : item,
          )
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: nextStatus == 'online'
            ? Colors.green.shade600
            : Colors.redAccent,
      ),
    );
  }

  Future<void> _testSshConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    SSHClient? client;

    try {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        keepAliveInterval: null,
      );
      await client.authenticated.timeout(const Duration(seconds: 8));
    } finally {
      client?.close();
    }
  }

  _ServerEndpoint? _serverEndpoint(HostingRecord record) {
    final host = record.primaryValue.trim();
    final port = record.tertiaryValue.trim();
    if (host.isEmpty) return null;

    final parsedPort = int.tryParse(port);
    if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
      return null;
    }

    return _ServerEndpoint(host: host, port: parsedPort);
  }

  Map<String, String> _serverSettingsFromDescription(String raw) {
    if (raw.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }
    } catch (_) {
      return {'notes': raw};
    }

    return {'notes': raw};
  }

  String _serverTestErrorMessage(Object error) {
    if (error is UnsupportedError) {
      return 'SSH tidak didukung di platform web/browser';
    }

    final raw = error.toString();
    if (raw.contains('Permission denied') || raw.contains('authenticate')) {
      return 'login SSH gagal';
    }
    if (raw.contains('timed out') || raw.contains('TimeoutException')) {
      return 'koneksi timeout';
    }

    return raw;
  }

  Future<void> _setNginxMode(HostingRecord record, bool enabled) async {
    if (record.id == null) {
      return;
    }

    try {
      await _dbHelper.updateHostingRecord(
        record.copyWith(
          status: enabled ? 'enabled' : 'available',
          isEnabled: enabled,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah mode Nginx: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _runBackupDatabase(HostingRecord record) async {
    final id = record.id;
    if (id == null || _runningBackupRecordIds.contains(id)) return;

    final runningAt = DateTime.now().toIso8601String();
    setState(() {
      _runningBackupRecordIds.add(id);
      _records = _records
          .map(
            (item) => item.id == id
                ? item.copyWith(status: 'running', updatedAt: runningAt)
                : item,
          )
          .toList();
    });

    try {
      await _dbHelper.updateHostingRecord(
        record.copyWith(status: 'running', updatedAt: runningAt),
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final finishedAt = DateTime.now().toIso8601String();
      final successDescription = _backupDescriptionWithResult(
        record.description,
        status: 'success',
        createdAt: finishedAt,
        message: 'Backup selesai',
        fileName: _backupFileName(record, finishedAt),
      );
      await _dbHelper.updateHostingRecord(
        record.copyWith(
          status: 'success',
          description: successDescription,
          updatedAt: finishedAt,
        ),
      );

      if (!mounted) return;
      setState(() {
        _runningBackupRecordIds.remove(id);
        _records = _records
            .map(
              (item) => item.id == id
                  ? item
                        .copyWith(status: 'success', updatedAt: finishedAt)
                        .copyWith(description: successDescription)
                  : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup ${record.title} selesai'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      final failedAt = DateTime.now().toIso8601String();
      final failedDescription = _backupDescriptionWithResult(
        record.description,
        status: 'failed',
        createdAt: failedAt,
        message: 'Backup gagal',
        fileName: _backupFileName(record, failedAt),
      );
      if (mounted) {
        setState(() {
          _runningBackupRecordIds.remove(id);
          _records = _records
              .map(
                (item) => item.id == id
                    ? item
                          .copyWith(status: 'failed', updatedAt: failedAt)
                          .copyWith(description: failedDescription)
                    : item,
              )
              .toList();
        });
      }
      try {
        await _dbHelper.updateHostingRecord(
          record.copyWith(
            status: 'failed',
            description: failedDescription,
            updatedAt: failedAt,
          ),
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup gagal: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _records.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_feature.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadRecords,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _feature.accentColor.withOpacity(
                theme.brightness == Brightness.dark ? 0.18 : 0.08,
              ),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _isNginxConfig
                  ? _buildNginxHeroCard(total)
                  : _buildHeroCard(total),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _loadRecords(),
                decoration: InputDecoration(
                  hintText: 'Cari ${_feature.title.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isNginxConfig)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildNginxViewToggle(),
              ),
            if (_isNginxConfig) const SizedBox(height: 12),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadRecords,
                      color: _feature.accentColor,
                      child: _isNginxConfig
                          ? _buildNginxContent()
                          : _isSubdomainConfig
                          ? _buildSubdomainContent()
                          : _isFileManagerConfig
                          ? _buildFileManagerContent()
                          : _buildGenericContent(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isFileManagerConfig
            ? _openFileManagerActionSheet
            : () => _openForm(),
        backgroundColor: _feature.accentColor,
        foregroundColor: Colors.white,
        icon: Icon(
          _isFileManagerConfig ? Icons.add_rounded : Icons.add_rounded,
        ),
        label: Text(
          _isFileManagerConfig
              ? 'Tambah'
              : _isNginxConfig
              ? 'Tambah Config'
              : 'Tambah',
        ),
      ),
    );
  }

  Widget _buildGenericContent() {
    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(_feature.icon, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada data ${_feature.title.toLowerCase()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan item pertama untuk mulai mengelola ${_feature.subtitle.toLowerCase()}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Slidable(
            key: ValueKey(record.id ?? '${record.featureKey}-$index'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                if (_feature.showEnabledToggle &&
                    !_isNginxConfig &&
                    !_isApiMonitoringConfig)
                  SlidableAction(
                    onPressed: (_) => _toggleEnabled(record),
                    backgroundColor: record.isEnabled
                        ? Colors.orange.shade700
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    icon: record.isEnabled
                        ? Icons.toggle_off_rounded
                        : Icons.toggle_on_rounded,
                    label: record.isEnabled ? 'Matikan' : 'Nyalakan',
                  ),
                SlidableAction(
                  onPressed: (_) => _openForm(record: record),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                ),
                SlidableAction(
                  onPressed: (_) => _deleteRecord(record),
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'Hapus',
                ),
              ],
            ),
            child: _isDomainConfig
                ? _buildDomainRecordCard(record)
                : _isBackupDatabaseConfig
                ? _buildBackupDatabaseRecordCard(record)
                : _buildRecordCard(record),
          ),
        );
      },
    );
  }

  Future<void> _openFileManagerActionSheet() async {
    if (_selectedFileManagerProject == 'Semua') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buka salah satu folder project terlebih dahulu'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Tambah File'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded),
              title: const Text('Tambah Folder'),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
            if (_fileManagerClipboardRecord != null &&
                _fileManagerClipboardAction != null)
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: Text(
                  _fileManagerClipboardAction == 'cut'
                      ? 'Paste hasil Cut'
                      : 'Paste hasil Copy',
                ),
                onTap: () => Navigator.pop(context, 'paste'),
              ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'paste') {
      await _pasteFileManagerClipboard();
      return;
    }

    await _showFileManagerCreateDialog(type: action);
  }

  Future<void> _showFileManagerCreateDialog({required String type}) async {
    final nameController = TextEditingController();
    final pathPreview = _fileManagerPath == '/' ? '/' : '$_fileManagerPath/';

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'file' ? 'Tambah File' : 'Tambah Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location: $pathPreview',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: type == 'file' ? 'File name' : 'Folder name',
                hintText: type == 'file' ? 'index.html' : 'assets',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    nameController.dispose();
    if (name == null || name.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final fullPath = _joinPath(_fileManagerPath, name);
    final record = HostingRecord(
      featureKey: _feature.key,
      title: name,
      primaryValue: fullPath,
      secondaryValue: type,
      tertiaryValue: _selectedFileManagerProject,
      description: type == 'file' ? 'Uploaded file $name.' : 'Folder $name.',
      status: widget.feature.defaultStatus,
      isEnabled: false,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _dbHelper.insertHostingRecord(record);
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(type == 'file' ? 'File ditambahkan' : 'Folder dibuat'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan item: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildFileManagerContent() {
    final showProjectFolders =
        _selectedFileManagerProject == 'Semua' && _fileManagerPath == '/';
    final projects = _safeFileManagerProjects;
    final records = _fileManagerVisibleRecords;
    final projectRecords = _selectedFileManagerProject == 'Semua'
        ? _records
        : _records
              .where(
                (record) => record.tertiaryValue == _selectedFileManagerProject,
              )
              .toList();

    if (showProjectFolders) {
      if (projects.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          children: [
            const SizedBox(height: 28),
            Icon(_feature.icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada project',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat project dulu agar folder file manager muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        children: [
          ...projects.map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFileManagerProjectFolderCard(project),
            ),
          ),
        ],
      );
    }

    if (records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        children: [
          _buildFileManagerToolbar(
            total: 0,
            folderCount: 0,
            fileCount: 0,
            allProjectItems: projectRecords.length,
          ),
          const SizedBox(height: 40),
          Icon(_feature.icon, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada file atau folder',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih project lalu tambahkan file atau folder untuk dikelola.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final folderCount = records
        .where((record) => record.secondaryValue.toLowerCase() != 'file')
        .length;
    final fileCount = records.length - folderCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        _buildFileManagerToolbar(
          total: records.length,
          folderCount: folderCount,
          fileCount: fileCount,
          allProjectItems: projectRecords.length,
        ),
        const SizedBox(height: 12),
        ...records.map(
          (record) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Slidable(
              key: ValueKey(
                record.id ?? '${record.featureKey}-${record.title}',
              ),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => _showFileManagerRenameDialog(record),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    icon: Icons.drive_file_rename_outline_rounded,
                    label: 'Rename',
                  ),
                  SlidableAction(
                    onPressed: (_) => _deleteFileManagerRecord(record),
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_rounded,
                    label: 'Hapus',
                  ),
                ],
              ),
              child: _buildFileManagerRecordCard(record),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileManagerToolbar({
    required int total,
    required int folderCount,
    required int fileCount,
    required int allProjectItems,
  }) {
    final project = _selectedFileManagerProject;
    final location = project == 'Semua'
        ? 'Semua Project'
        : _fileManagerPath == '/'
        ? project
        : '$project$_fileManagerPath';
    final canGoBack = _fileManagerPath != '/' || project != 'Semua';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (canGoBack) ...[
                IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    setState(() {
                      if (_fileManagerPath != '/') {
                        _fileManagerPath = _parentPath(_fileManagerPath);
                      } else {
                        _selectedFileManagerProject = 'Semua';
                      }
                    });
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _feature.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  color: _feature.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFileManagerMetric(
                Icons.folder_rounded,
                '$folderCount folder',
              ),
              const SizedBox(width: 8),
              _buildFileManagerMetric(
                Icons.insert_drive_file_rounded,
                '$fileCount file',
              ),
              const SizedBox(width: 8),
              _buildFileManagerMetric(Icons.list_alt_rounded, '$total item'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileManagerMetric(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _feature.accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: _feature.accentColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _feature.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileManagerProjectFolderCard(String project) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedFileManagerProject = project;
            _fileManagerPath = '/';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.amber.shade800.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_special_rounded,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFileManagerItemActions(HostingRecord record) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut_rounded),
              title: const Text('Cut'),
              onTap: () => Navigator.pop(context, 'cut'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Hapus'),
              textColor: Colors.red.shade600,
              iconColor: Colors.red.shade600,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;

    switch (action) {
      case 'rename':
        await _showFileManagerRenameDialog(record);
        break;
      case 'copy':
      case 'cut':
        setState(() {
          _fileManagerClipboardRecord = record;
          _fileManagerClipboardAction = action;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'cut' ? 'Item di-cut' : 'Item di-copy'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        break;
      case 'delete':
        await _deleteFileManagerRecord(record);
        break;
    }
  }

  Future<void> _deleteFileManagerRecord(HostingRecord record) async {
    final isFolder = record.secondaryValue.toLowerCase() != 'file';
    final childCount = isFolder
        ? _records.where((child) {
            final recordPath = _normalizePath(record.primaryValue);
            final childPath = _normalizePath(child.primaryValue);
            return child.tertiaryValue == record.tertiaryValue &&
                childPath.startsWith('$recordPath/');
          }).length
        : 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${isFolder ? 'folder' : 'file'}'),
        content: Text(
          childCount > 0
              ? '"${record.title}" dan $childCount item di dalamnya akan dihapus.'
              : '"${record.title}" akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || record.id == null) return;

    try {
      if (isFolder) {
        final recordPath = _normalizePath(record.primaryValue);
        final descendants = _records.where((child) {
          final childPath = _normalizePath(child.primaryValue);
          return child.tertiaryValue == record.tertiaryValue &&
              childPath.startsWith('$recordPath/') &&
              child.id != null;
        });

        for (final child in descendants) {
          await _dbHelper.deleteHostingRecord(child.id!);
        }
      }

      await _dbHelper.deleteHostingRecord(record.id!);
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFolder ? 'Folder dihapus' : 'File dihapus'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus item: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showFileManagerRenameDialog(HostingRecord record) async {
    final controller = TextEditingController(text: record.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newName == null || newName.isEmpty || newName == record.title) return;

    final oldPath = _normalizePath(record.primaryValue);
    final newPath = _joinPath(_parentPath(oldPath), newName);
    final now = DateTime.now().toIso8601String();

    try {
      await _dbHelper.updateHostingRecord(
        record.copyWith(title: newName, primaryValue: newPath, updatedAt: now),
      );

      if (record.secondaryValue.toLowerCase() != 'file') {
        await _updateFileManagerDescendantPaths(
          project: record.tertiaryValue,
          oldParentPath: oldPath,
          newParentPath: newPath,
          updatedAt: now,
        );
      }

      if (_fileManagerPath == oldPath) {
        _fileManagerPath = newPath;
      }

      await _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal rename item: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pasteFileManagerClipboard() async {
    final source = _fileManagerClipboardRecord;
    final action = _fileManagerClipboardAction;
    if (source == null || action == null) return;

    final destinationProject = _selectedFileManagerProject;
    if (destinationProject == 'Semua') return;

    final now = DateTime.now().toIso8601String();
    final targetTitle = _availableFileManagerName(
      source.title,
      destinationProject,
      _fileManagerPath,
    );
    final targetPath = _joinPath(_fileManagerPath, targetTitle);

    try {
      if (action == 'cut') {
        final oldPath = _normalizePath(source.primaryValue);
        final destinationPath = _normalizePath(_fileManagerPath);
        final isFolder = source.secondaryValue.toLowerCase() != 'file';
        final movingIntoItself =
            isFolder &&
            source.tertiaryValue == destinationProject &&
            (destinationPath == oldPath ||
                destinationPath.startsWith('$oldPath/'));

        if (movingIntoItself) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Folder tidak bisa dipindahkan ke dalam dirinya'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        await _dbHelper.updateHostingRecord(
          source.copyWith(
            title: targetTitle,
            primaryValue: targetPath,
            tertiaryValue: destinationProject,
            updatedAt: now,
          ),
        );

        if (source.secondaryValue.toLowerCase() != 'file') {
          await _updateFileManagerDescendantPaths(
            project: source.tertiaryValue,
            oldParentPath: oldPath,
            newParentPath: targetPath,
            updatedAt: now,
            newProject: destinationProject,
          );
        }

        _fileManagerClipboardRecord = null;
        _fileManagerClipboardAction = null;
      } else {
        await _copyFileManagerRecordTree(
          source: source,
          targetTitle: targetTitle,
          targetPath: targetPath,
          targetProject: destinationProject,
          createdAt: now,
        );
      }

      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'cut' ? 'Item dipindahkan' : 'Item disalin'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal paste item: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _copyFileManagerRecordTree({
    required HostingRecord source,
    required String targetTitle,
    required String targetPath,
    required String targetProject,
    required String createdAt,
  }) async {
    await _dbHelper.insertHostingRecord(
      HostingRecord(
        featureKey: source.featureKey,
        title: targetTitle,
        primaryValue: targetPath,
        secondaryValue: source.secondaryValue,
        tertiaryValue: targetProject,
        description: source.description,
        status: source.status,
        isEnabled: source.isEnabled,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    if (source.secondaryValue.toLowerCase() == 'file') return;

    final sourcePath = _normalizePath(source.primaryValue);
    final descendants = _records.where((record) {
      final path = _normalizePath(record.primaryValue);
      return record.tertiaryValue == source.tertiaryValue &&
          path.startsWith('$sourcePath/');
    });

    for (final child in descendants) {
      final childPath = _normalizePath(child.primaryValue);
      final suffix = childPath.substring(sourcePath.length);
      await _dbHelper.insertHostingRecord(
        HostingRecord(
          featureKey: child.featureKey,
          title: child.title,
          primaryValue: '$targetPath$suffix',
          secondaryValue: child.secondaryValue,
          tertiaryValue: targetProject,
          description: child.description,
          status: child.status,
          isEnabled: child.isEnabled,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
    }
  }

  Future<void> _updateFileManagerDescendantPaths({
    required String project,
    required String oldParentPath,
    required String newParentPath,
    required String updatedAt,
    String? newProject,
  }) async {
    final descendants = _records.where((record) {
      final path = _normalizePath(record.primaryValue);
      return record.tertiaryValue == project &&
          path.startsWith('$oldParentPath/') &&
          record.id != null;
    });

    for (final child in descendants) {
      final childPath = _normalizePath(child.primaryValue);
      final suffix = childPath.substring(oldParentPath.length);
      await _dbHelper.updateHostingRecord(
        child.copyWith(
          primaryValue: '$newParentPath$suffix',
          tertiaryValue: newProject ?? child.tertiaryValue,
          updatedAt: updatedAt,
        ),
      );
    }
  }

  String _availableFileManagerName(
    String name,
    String project,
    String parentPath,
  ) {
    final baseName = name.trim().isEmpty ? 'untitled' : name.trim();
    final normalizedParent = _normalizePath(parentPath);
    var candidate = baseName;
    var counter = 1;

    while (_records.any(
      (record) =>
          record.tertiaryValue == project &&
          _parentPath(record.primaryValue) == normalizedParent &&
          record.title.toLowerCase() == candidate.toLowerCase(),
    )) {
      counter += 1;
      candidate = '$baseName copy $counter';
    }

    return candidate;
  }

  String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '/';

    var normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _parentPath(String path) {
    final normalized = _normalizePath(path);
    if (normalized == '/') return '/';
    final index = normalized.lastIndexOf('/');
    if (index <= 0) return '/';
    return normalized.substring(0, index);
  }

  String _joinPath(String parent, String name) {
    final cleanName = name.trim().replaceAll('/', '');
    final normalizedParent = _normalizePath(parent);
    if (normalizedParent == '/') return '/$cleanName';
    return '$normalizedParent/$cleanName';
  }

  bool _hasCurrentFileManagerPath(List<HostingRecord> records) {
    if (_fileManagerPath == '/') return true;

    return records.any(
      (record) =>
          record.tertiaryValue == _selectedFileManagerProject &&
          _normalizePath(record.primaryValue) == _fileManagerPath,
    );
  }

  Widget _buildSubdomainContent() {
    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(_feature.icon, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada data ${_feature.title.toLowerCase()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan subdomain dan hostname internal yang ingin diarahkan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Slidable(
            key: ValueKey(record.id ?? '${record.featureKey}-$index'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _openForm(record: record),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                ),
                SlidableAction(
                  onPressed: (_) => _deleteRecord(record),
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'Hapus',
                ),
              ],
            ),
            child: _buildSubdomainRecordCard(record),
          ),
        );
      },
    );
  }

  Widget _buildNginxContent() {
    final visibleRecords = _nginxVisibleRecords;
    final showingAvailable = _nginxViewMode == _NginxViewMode.available;
    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(_feature.icon, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada config Nginx',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan konfigurasi Nginx, lalu aktifkan saat siap dipakai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        if (visibleRecords.isEmpty)
          _buildEmptySectionMessage('Belum ada config')
        else
          ...visibleRecords.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Slidable(
                key: ValueKey(record.id ?? '${record.featureKey}-nginx'),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    if (showingAvailable)
                      SlidableAction(
                        onPressed: (_) => _openForm(record: record),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                      ),
                    SlidableAction(
                      onPressed: (_) => _deleteRecord(record),
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_rounded,
                      label: 'Hapus',
                    ),
                  ],
                ),
                child: _buildNginxRecordCard(
                  record,
                  isEnabled: record.isEnabled,
                  showToggle: showingAvailable,
                  onToggle: (value) => _setNginxMode(record, value),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNginxViewToggle() {
    final isAvailable = _nginxViewMode == _NginxViewMode.available;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (_nginxViewMode != _NginxViewMode.available) {
                  setState(() {
                    _nginxViewMode = _NginxViewMode.available;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? _feature.accentColor.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: isAvailable
                          ? _feature.accentColor
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Konfigurasi',
                      style: TextStyle(
                        color: isAvailable
                            ? _feature.accentColor
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (_nginxViewMode != _NginxViewMode.enabled) {
                  setState(() {
                    _nginxViewMode = _NginxViewMode.enabled;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isAvailable
                      ? Colors.green.shade600.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 18,
                      color: !isAvailable
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: !isAvailable
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySectionMessage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
    );
  }

  Widget _buildHeroCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _feature.accentColor,
            _feature.accentColor.withOpacity(0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _feature.accentColor.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(_feature.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _feature.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0 ? 'Siap diisi' : '$total item di panel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNginxHeroCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _feature.accentColor,
            _feature.accentColor.withOpacity(0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _feature.accentColor.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(_feature.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _feature.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0 ? 'Siap diisi' : '$total config Nginx',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubdomainRecordCard(HostingRecord record) {
    final titleParts = record.title.split('.');
    final domainFromTitle = titleParts.length > 1
        ? titleParts.skip(1).join('.')
        : '';
    final serviceText = record.tertiaryValue.startsWith('proxy://')
        ? record.primaryValue
        : record.tertiaryValue.isEmpty
        ? _feature.tertiaryHint
        : record.tertiaryValue;
    final domainText = record.secondaryValue.contains('.')
        ? record.secondaryValue
        : domainFromTitle.isNotEmpty
        ? domainFromTitle
        : record.secondaryValue.isEmpty
        ? _feature.secondaryHint
        : record.secondaryValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _feature.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_feature.icon, color: _feature.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$domainText -> $serviceText',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _statusLabel(record.status),
                style: TextStyle(
                  color: _statusColor(record.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNginxRecordCard(
    HostingRecord record, {
    required bool isEnabled,
    required bool showToggle,
    ValueChanged<bool>? onToggle,
  }) {
    final preview = record.description.isNotEmpty
        ? record.description
        : _buildNginxConfigPreview(record);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _feature.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_feature.icon, color: _feature.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      record.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _nginxSummary(record),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (showToggle)
                    Switch.adaptive(
                      value: isEnabled,
                      activeColor: Colors.green.shade600,
                      onChanged: onToggle,
                    ),
                ],
              ),
              if (!showToggle) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  ),
                  child: Text(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _nginxSummary(HostingRecord record) {
    final port = record.primaryValue.isEmpty ? '-' : record.primaryValue;
    final target = record.secondaryValue.isEmpty ? '-' : record.secondaryValue;
    final type = record.tertiaryValue.isEmpty ? '-' : record.tertiaryValue;
    return 'Port $port | $type | $target';
  }

  String _buildNginxConfigPreview(HostingRecord record) {
    final serverName = record.title;
    final port = record.primaryValue.isEmpty ? '80' : record.primaryValue;
    final targetPath = record.secondaryValue;
    final projectType = record.tertiaryValue;
    final normalizedType = projectType.toLowerCase();
    final isNode = normalizedType.contains('node');
    final isReact = normalizedType.contains('react');

    if (isNode) {
      return '''
server {
    listen $port;
    server_name $serverName;

    location / {
        proxy_pass $targetPath;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}''';
    }

    return '''
server {
    listen $port;
    server_name $serverName;
    root $targetPath${isReact ? '' : '/public'};
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ /index.${isReact ? 'html' : 'php'}?\$query_string;
    }
}''';
  }

  Widget _buildRecordCard(HostingRecord record) {
    if (_isApiMonitoringConfig) {
      return _buildApiMonitoringRecordCard(record);
    }

    final rows = _simpleRecordRows(record);
    final isTestingServer =
        record.id != null && _testingServerRecordIds.contains(record.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _feature.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_feature.icon, color: _feature.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      record.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_isServerConfig) ...[
                    const SizedBox(width: 10),
                    _buildServerStatusBadge(record.status),
                  ],
                ],
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            row.label,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            row.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_isServerConfig) ...[
                const SizedBox(height: 8),
                _buildServerMonitoringMeta(record),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isTestingServer
                        ? null
                        : () => _testServerStatus(record),
                    icon: isTestingServer
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _feature.accentColor,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(isTestingServer ? 'Testing...' : 'Test'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _feature.accentColor,
                      side: BorderSide(
                        color: _feature.accentColor.withOpacity(0.28),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerMonitoringMeta(HostingRecord record) {
    final id = record.id;
    final latency = id == null ? null : _serverLatencyMsById[id];
    final lastChecked = id == null ? null : _serverLastCheckedById[id];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildApiIconChip(
          icon: Icons.speed_rounded,
          label: latency == null ? '-' : '${latency}ms',
          color: Colors.teal,
        ),
        _buildApiIconChip(
          icon: Icons.schedule_rounded,
          label: lastChecked == null ? '-' : _formatApiLastChecked(lastChecked),
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildServerStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Icon(
        status.toLowerCase() == 'online'
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildApiMonitoringRecordCard(HostingRecord record) {
    final isTestingApi =
        record.id != null && _testingApiRecordIds.contains(record.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _feature.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_feature.icon, color: _feature.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.primaryValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildApiStatusBadge(record.status),
                ],
              ),
              const SizedBox(height: 14),
              _buildApiMonitoringMeta(record),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isTestingApi
                      ? null
                      : () => _testApiEndpoint(record),
                  icon: isTestingApi
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _feature.accentColor,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(isTestingApi ? 'Testing...' : 'Test'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _feature.accentColor,
                    side: BorderSide(
                      color: _feature.accentColor.withOpacity(0.28),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiStatusBadge(String status) {
    final color = _apiStatusColor(status);

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Icon(_apiStatusIcon(status), color: color, size: 20),
    );
  }

  Widget _buildBackupDatabaseRecordCard(HostingRecord record) {
    final settings = _backupSettingsFromDescription(record.description);
    final results = _backupResultsForRecord(record);
    final isRunning =
        record.id != null && _runningBackupRecordIds.contains(record.id);
    final status = isRunning ? 'running' : record.status;
    final statusColor = _statusColor(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _feature.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_feature.icon, color: _feature.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.primaryValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildApiIconChip(
                    icon: _backupStatusIcon(status),
                    label: _statusLabel(status),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildApiIconChip(
                    icon: Icons.storage_rounded,
                    label: record.secondaryValue,
                    color: Colors.indigo,
                  ),
                  _buildApiIconChip(
                    icon: Icons.settings_ethernet_rounded,
                    label: record.tertiaryValue,
                    color: Colors.blueGrey,
                  ),
                  _buildApiIconChip(
                    icon: Icons.event_repeat_rounded,
                    label: settings['schedule'] ?? '-',
                    color: Colors.teal,
                  ),
                  _buildApiIconChip(
                    icon: Icons.history_rounded,
                    label: settings['retention'] ?? '-',
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildBackupResultsDropdown(results),
              if ((settings['notes'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  settings['notes']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isRunning
                      ? null
                      : () => _runBackupDatabase(record),
                  icon: isRunning
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _feature.accentColor,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(isRunning ? 'Running...' : 'Run Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _feature.accentColor,
                    side: BorderSide(
                      color: _feature.accentColor.withOpacity(0.28),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> _backupSettingsFromDescription(String raw) {
    if (raw.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }
    } catch (_) {
      return {'notes': raw};
    }

    return {'notes': raw};
  }

  Widget _buildBackupResultsDropdown(List<Map<String, String>> results) {
    final latest = results.isEmpty ? null : results.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(Icons.inventory_2_rounded, color: _feature.accentColor),
          title: Text(
            latest == null ? 'List Backup' : 'List Backup',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          children: results.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jalankan backup untuk membuat hasil pertama.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ]
              : results
                    .map(
                      (result) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              _backupStatusIcon(result['status'] ?? ''),
                              size: 18,
                              color: _statusColor(result['status'] ?? ''),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result['fileName'] ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${result['message'] ?? '-'} • ${_formatBackupResultTime(result['createdAt'] ?? '')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }

  List<Map<String, String>> _backupResultsFromDescription(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['results'] is List) {
        return (decoded['results'] as List)
            .whereType<Map>()
            .map(
              (result) => result.map(
                (key, value) =>
                    MapEntry(key.toString(), value?.toString() ?? ''),
              ),
            )
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  List<Map<String, String>> _backupResultsForRecord(HostingRecord record) {
    final results = _backupResultsFromDescription(record.description);
    if (results.isNotEmpty) return results;
    if (record.updatedAt.trim().isEmpty) return const [];

    final status = record.status.toLowerCase() == 'failed'
        ? 'failed'
        : 'success';

    return [
      {
        'status': status,
        'createdAt': record.updatedAt,
        'message': status == 'success'
            ? 'Backup awal tersedia'
            : 'Backup awal gagal',
        'fileName': _backupFileName(record, record.updatedAt),
      },
    ];
  }

  String _backupDescriptionWithResult(
    String raw, {
    required String status,
    required String createdAt,
    required String message,
    required String fileName,
  }) {
    final payload = _backupPayloadFromDescription(raw);
    final results = _backupResultsFromDescription(raw);
    results.insert(0, {
      'status': status,
      'createdAt': createdAt,
      'message': message,
      'fileName': fileName,
    });

    payload['results'] = results.take(10).toList();
    return jsonEncode(payload);
  }

  Map<String, dynamic> _backupPayloadFromDescription(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return {'notes': raw};
    }

    return {};
  }

  String _backupFileName(HostingRecord record, String createdAt) {
    final parsed = DateTime.tryParse(createdAt) ?? DateTime.now();
    final stamp =
        '${parsed.year}${parsed.month.toString().padLeft(2, '0')}${parsed.day.toString().padLeft(2, '0')}_${parsed.hour.toString().padLeft(2, '0')}${parsed.minute.toString().padLeft(2, '0')}';
    final dbType = record.secondaryValue
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safeName = record.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'backup_${dbType}_${safeName}_$stamp.zip';
  }

  IconData _backupStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'ready':
        return Icons.check_circle_rounded;
      case 'running':
        return Icons.sync_rounded;
      case 'failed':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatBackupResultTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildApiMonitoringMeta(HostingRecord record) {
    final id = record.id;
    final latency = id == null ? null : _apiLatencyMsById[id];
    final lastChecked = id == null ? null : _apiLastCheckedById[id];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildApiIconChip(
          icon: Icons.timer_rounded,
          label: '${record.secondaryValue}s',
          color: Colors.blueGrey,
        ),
        _buildApiIconChip(
          icon: Icons.speed_rounded,
          label: latency == null ? '-' : '${latency}ms',
          color: Colors.teal,
        ),
        _buildApiIconChip(
          icon: Icons.schedule_rounded,
          label: lastChecked == null ? '-' : _formatApiLastChecked(lastChecked),
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildApiIconChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label.isEmpty ? '-' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _apiStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Icons.check_circle_rounded;
      case 'degraded':
        return Icons.warning_amber_rounded;
      case 'down':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  Color _apiStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green.shade600;
      case 'degraded':
        return Colors.orange.shade700;
      case 'down':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildFileManagerRecordCard(HostingRecord record) {
    final isFile = record.secondaryValue.toLowerCase() == 'file';
    final icon = isFile
        ? Icons.insert_drive_file_rounded
        : Icons.folder_rounded;
    final iconColor = isFile ? Colors.blueGrey.shade600 : Colors.amber.shade800;
    final typeLabel = isFile ? 'FILE' : 'FOLDER';
    final path = record.primaryValue.isEmpty ? '/' : record.primaryValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isFile
            ? () => _showFileManagerItemActions(record)
            : () {
                setState(() {
                  _fileManagerPath = _normalizePath(record.primaryValue);
                });
              },
        onLongPress: () => _showFileManagerItemActions(record),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.account_tree_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.tertiaryValue.isEmpty ? '-' : record.tertiaryValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_left_rounded,
                color: Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_RecordInfoRow> _simpleRecordRows(HostingRecord record) {
    switch (_feature.key) {
      case 'project':
        return [
          _RecordInfoRow('Domain', record.primaryValue),
          _RecordInfoRow('Stack', record.tertiaryValue),
        ];
      case 'file_manager':
        return [
          _RecordInfoRow('Path', record.primaryValue),
          _RecordInfoRow('Project', record.tertiaryValue),
        ];
      case 'api_monitoring':
        return [_RecordInfoRow('URL', record.primaryValue)];
      case 'other_services':
        return [
          _RecordInfoRow('Database', record.primaryValue),
          _RecordInfoRow('Jenis', record.secondaryValue),
          _RecordInfoRow('Port', record.tertiaryValue),
        ];
      case 'server':
        return [
          _RecordInfoRow('Host', record.primaryValue),
          _RecordInfoRow('Port', record.tertiaryValue),
          _RecordInfoRow('User', record.secondaryValue),
        ];
      default:
        return [
          _RecordInfoRow(widget.feature.primaryLabel, record.primaryValue),
          _RecordInfoRow(widget.feature.secondaryLabel, record.secondaryValue),
        ];
    }
  }

  String _formatApiLastChecked(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Widget _buildDomainRecordCard(HostingRecord record) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _feature.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_feature.icon, color: _feature.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      record.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildNameserverInfo('Nameserver 1', record.primaryValue),
              const SizedBox(height: 10),
              _buildNameserverInfo('Nameserver 2', record.secondaryValue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameserverInfo(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _feature.accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'enabled':
      case 'active':
      case 'healthy':
      case 'online':
      case 'verified':
      case 'deployed':
      case 'ready':
      case 'success':
        return Colors.green.shade700;
      case 'paused':
      case 'maintenance':
      case 'degraded':
      case 'draft':
      case 'planning':
      case 'review':
      case 'running':
      case 'available':
        return Colors.orange.shade700;
      case 'disabled':
      case 'expired':
      case 'down':
      case 'offline':
      case 'failed':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'enabled':
        return 'Berjalan';
      case 'available':
        return 'Config';
      case 'active':
        return 'Berjalan';
      case 'disabled':
        return 'Nonaktif';
      case 'healthy':
        return 'Sehat';
      case 'degraded':
        return 'Perlu cek';
      case 'down':
        return 'Down';
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      case 'verified':
        return 'Terverifikasi';
      case 'expired':
        return 'Expired';
      case 'deployed':
        return 'Deploy';
      case 'ready':
        return 'Siap';
      case 'success':
        return 'Berhasil';
      case 'failed':
        return 'Gagal';
      case 'running':
        return 'Berjalan';
      case 'paused':
        return 'Pause';
      case 'maintenance':
        return 'Maintenance';
      case 'planning':
        return 'Planning';
      case 'review':
        return 'Review';
      default:
        return status.isEmpty ? '-' : status;
    }
  }
}

class _RecordInfoRow {
  final String label;
  final String value;

  const _RecordInfoRow(this.label, this.value);
}

class _ServerEndpoint {
  final String host;
  final int port;

  const _ServerEndpoint({required this.host, required this.port});
}
