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

part 'hosting_crud_file_manager.dart';
part 'hosting_crud_backup_database.dart';
part 'hosting_crud_monitoring.dart';
part 'hosting_crud_nginx.dart';
part 'hosting_crud_domain.dart';
part 'hosting_crud_subdomain.dart';
part 'hosting_crud_project.dart';

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
  bool get _isProjectConfig => _feature.key == 'project';
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

  void _safeSetState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

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
                : _isProjectConfig
                ? _buildProjectRecordCard(record)
                : _isBackupDatabaseConfig
                ? _buildBackupDatabaseRecordCard(record)
                : _buildRecordCard(record),
          ),
        );
      },
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
