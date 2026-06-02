import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../models/hosting_record_model.dart';
import 'hosting_feature_spec.dart';

class HostingRecordFormPage extends StatefulWidget {
  final HostingFeatureSpec feature;
  final HostingRecord? record;

  const HostingRecordFormPage({super.key, required this.feature, this.record});

  @override
  State<HostingRecordFormPage> createState() => _HostingRecordFormPageState();
}

class _HostingRecordFormPageState extends State<HostingRecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _tertiaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _backupScheduleController = TextEditingController();
  final _backupTargetController = TextEditingController();
  final _backupRetentionController = TextEditingController();
  final _serverPasswordController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<String>? _domainOptions;
  List<String>? _projectOptions;
  String? _selectedDomain;
  String? _selectedProject;
  String _nginxProjectType = 'Laravel';
  String _fileManagerType = 'folder';
  bool _isSaving = false;

  bool get _isNginxFeature => widget.feature.key == 'nginx_config';
  bool get _isSubdomainFeature => widget.feature.key == 'subdomain';
  bool get _isDomainFeature => widget.feature.key == 'domain';
  bool get _isProjectFeature => widget.feature.key == 'project';
  bool get _isFileManagerFeature => widget.feature.key == 'file_manager';
  bool get _isBackupDatabaseFeature => widget.feature.key == 'other_services';
  bool get _isServerFeature => widget.feature.key == 'server';
  List<String> get _safeDomainOptions => _domainOptions ?? const [];
  List<String> get _safeProjectOptions => _projectOptions ?? const [];

  @override
  void initState() {
    super.initState();
    final record = widget.record;

    if (_isSubdomainFeature) {
      _setSubdomainInitialValues(record);
      _loadDomainOptions();
    } else if (_isNginxFeature) {
      _setNginxInitialValues(record);
    } else if (_isDomainFeature) {
      _titleController.text = record?.title ?? '';
      _primaryController.text = record?.primaryValue ?? '';
      _secondaryController.text = record?.secondaryValue ?? '';
    } else if (_isProjectFeature) {
      _titleController.text = record?.title ?? '';
      _selectedDomain = record?.primaryValue.isNotEmpty == true
          ? record!.primaryValue
          : null;
      _tertiaryController.text = record?.tertiaryValue ?? '';
      _loadProjectDomainOptions();
    } else if (_isFileManagerFeature) {
      _titleController.text = record?.title ?? '';
      _primaryController.text = record?.primaryValue ?? '';
      _fileManagerType = record?.secondaryValue == 'file' ? 'file' : 'folder';
      _selectedProject = record?.tertiaryValue.isNotEmpty == true
          ? record!.tertiaryValue
          : null;
      _loadFileManagerProjectOptions();
    } else if (_isServerFeature) {
      _setServerInitialValues(record);
    } else {
      _titleController.text = record?.title ?? '';
      _primaryController.text = record?.primaryValue ?? '';
      _secondaryController.text = record?.secondaryValue ?? '';
      _tertiaryController.text = record?.tertiaryValue ?? '';
    }

    if (_isBackupDatabaseFeature) {
      _setBackupDatabaseInitialValues(record);
    } else if (_isServerFeature) {
      final settings = _serverSettingsFromDescription(
        record?.description ?? '',
      );
      _descriptionController.text = settings['notes'] ?? '';
    } else {
      _descriptionController.text = record?.description ?? '';
    }
  }

  void _setServerInitialValues(HostingRecord? record) {
    final settings = _serverSettingsFromDescription(record?.description ?? '');

    _titleController.text = record?.title ?? '';
    _primaryController.text = record?.primaryValue ?? '';
    _secondaryController.text = record?.secondaryValue == '-'
        ? ''
        : record?.secondaryValue ?? '';
    _tertiaryController.text = record?.tertiaryValue ?? '22';
    _serverPasswordController.text = settings['password'] ?? '';
  }

  void _setBackupDatabaseInitialValues(HostingRecord? record) {
    final settings = _backupSettingsFromDescription(record?.description ?? '');
    _backupScheduleController.text = settings['schedule'] ?? '02:00';
    _backupTargetController.text = settings['target'] ?? '';
    _backupRetentionController.text = settings['retention'] ?? 'Daily';
    _descriptionController.text = settings['notes'] ?? '';
  }

  void _setNginxInitialValues(HostingRecord? record) {
    if (record == null) {
      _nginxProjectType = 'Laravel';
      return;
    }

    _titleController.text = record.title;
    _primaryController.text = record.primaryValue;
    _secondaryController.text = record.secondaryValue;

    final savedType = record.tertiaryValue.trim();
    const options = ['Laravel', 'React', 'Node.js'];
    _nginxProjectType = options.contains(savedType) ? savedType : 'Laravel';
  }

  void _setSubdomainInitialValues(HostingRecord? record) {
    if (record == null) {
      _primaryController.text = '';
      _tertiaryController.text = '';
      return;
    }

    final titleParts = record.title.split('.');
    final domainFromTitle = titleParts.length > 1
        ? titleParts.skip(1).join('.')
        : '';
    final savedDomain = record.secondaryValue.contains('.')
        ? record.secondaryValue
        : domainFromTitle;

    _selectedDomain = savedDomain.isEmpty ? null : savedDomain;
    _primaryController.text = record.primaryValue.contains(':')
        ? titleParts.first
        : record.primaryValue;
    _tertiaryController.text = record.tertiaryValue.startsWith('proxy://')
        ? record.primaryValue
        : record.tertiaryValue;
  }

  Future<void> _loadDomainOptions() async {
    final domains = await _dbHelper.getHostingRecords(
      HostingFeatures.domain.key,
    );
    if (!mounted) return;

    final options =
        domains
            .map((record) => record.title.trim())
            .where((domain) => domain.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final selected = _selectedDomain;
    if (selected != null &&
        selected.isNotEmpty &&
        !options.contains(selected)) {
      options.add(selected);
      options.sort();
    }

    setState(() {
      _domainOptions = options;
      _selectedDomain ??= options.isNotEmpty ? options.first : null;
    });
  }

  Future<void> _loadProjectDomainOptions() async {
    final domains = await _dbHelper.getHostingRecords(
      HostingFeatures.domain.key,
    );
    final subdomains = await _dbHelper.getHostingRecords(
      HostingFeatures.subdomain.key,
    );
    final projects = await _dbHelper.getHostingRecords(
      HostingFeatures.project.key,
    );
    if (!mounted) return;

    final usedDomains = projects
        .where((record) => record.id != widget.record?.id)
        .map((record) => record.primaryValue.trim())
        .where((domain) => domain.isNotEmpty)
        .toSet();

    final options =
        <String>{
              ...domains.map((record) => record.title.trim()),
              ...subdomains.map((record) => record.title.trim()),
            }
            .where(
              (domain) => domain.isNotEmpty && !usedDomains.contains(domain),
            )
            .toList()
          ..sort();

    final selected = _selectedDomain;
    if (selected != null &&
        selected.isNotEmpty &&
        !options.contains(selected)) {
      options.add(selected);
      options.sort();
    }

    setState(() {
      _domainOptions = options;
      _selectedDomain ??= options.isNotEmpty ? options.first : null;
    });
  }

  Future<bool> _isProjectDomainAvailable(String domain) async {
    final projects = await _dbHelper.getHostingRecords(
      HostingFeatures.project.key,
    );

    return !projects.any(
      (record) =>
          record.id != widget.record?.id &&
          record.primaryValue.trim() == domain,
    );
  }

  Future<void> _loadFileManagerProjectOptions() async {
    final projects = await _dbHelper.getHostingRecords(
      HostingFeatures.project.key,
    );
    if (!mounted) return;

    final options =
        projects
            .map((record) => record.title.trim())
            .where((project) => project.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final selected = _selectedProject;
    if (selected != null &&
        selected.isNotEmpty &&
        !options.contains(selected)) {
      options.add(selected);
      options.sort();
    }

    setState(() {
      _projectOptions = options;
      _selectedProject ??= options.isNotEmpty ? options.first : null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    _tertiaryController.dispose();
    _descriptionController.dispose();
    _backupScheduleController.dispose();
    _backupTargetController.dispose();
    _backupRetentionController.dispose();
    _serverPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    final previous = widget.record;
    final selectedDomain = _selectedDomain?.trim() ?? '';

    if ((_isSubdomainFeature || _isProjectFeature) && selectedDomain.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih domain terlebih dahulu'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isProjectFeature) {
      final domainAvailable = await _isProjectDomainAvailable(selectedDomain);
      if (!mounted) return;
      if (!domainAvailable) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Domain sudah digunakan oleh project lain'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _loadProjectDomainOptions();
        return;
      }
    }

    if (_isFileManagerFeature && (_selectedProject?.trim().isEmpty ?? true)) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih project terlebih dahulu'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final subdomainTitle = _isSubdomainFeature
        ? '${_primaryController.text.trim()}.$selectedDomain'
        : _titleController.text.trim();
    final subdomainDescription = _isSubdomainFeature
        ? 'Arahkan $subdomainTitle ke ${_tertiaryController.text.trim()}'
        : _descriptionController.text.trim();
    final domainNameservers = _domainNameservers(
      previous?.primaryValue,
      previous?.secondaryValue,
    );
    final simpleValues = _simpleFeatureValues();

    final record = HostingRecord(
      id: previous?.id,
      featureKey: widget.feature.key,
      title: _isDomainFeature
          ? _titleController.text.trim()
          : _isSubdomainFeature
          ? subdomainTitle
          : simpleValues.title,
      primaryValue: _isDomainFeature
          ? domainNameservers.first
          : _isSubdomainFeature
          ? _primaryController.text.trim()
          : simpleValues.primary,
      secondaryValue: _isDomainFeature
          ? domainNameservers.last
          : _isSubdomainFeature
          ? selectedDomain
          : simpleValues.secondary,
      tertiaryValue: _isDomainFeature
          ? 'Cloudflare'
          : _isSubdomainFeature
          ? _tertiaryController.text.trim()
          : simpleValues.tertiary,
      description: _isDomainFeature
          ? 'Gunakan nameserver berikut untuk mengarahkan domain.'
          : _isSubdomainFeature
          ? subdomainDescription
          : simpleValues.description,
      status: _isSubdomainFeature || _isDomainFeature
          ? widget.feature.defaultStatus
          : simpleValues.status,
      isEnabled: _isSubdomainFeature
          ? true
          : _isDomainFeature
          ? false
          : simpleValues.isEnabled,
      createdAt: previous?.createdAt.isNotEmpty == true
          ? previous!.createdAt
          : now,
      updatedAt: now,
    );

    try {
      if (previous == null) {
        await _dbHelper.insertHostingRecord(record);
      } else {
        await _dbHelper.updateHostingRecord(record);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.feature.title} berhasil disimpan'),
          backgroundColor: Colors.green.shade600,
        ),
      );

      if (_isDomainFeature) {
        await _showNameserverDialog(record);
        if (!mounted) return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan ${widget.feature.title.toLowerCase()}: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  _SimpleFeatureValues _simpleFeatureValues() {
    final title = _titleController.text.trim();
    final primary = _primaryController.text.trim();
    final secondary = _secondaryController.text.trim();
    final tertiary = _tertiaryController.text.trim();
    final description = _descriptionController.text.trim();

    switch (widget.feature.key) {
      case 'nginx_config':
        final configPreview = _buildNginxConfigPreview(
          serverName: title,
          port: primary,
          targetPath: secondary,
          projectType: _nginxProjectType,
        );

        return _SimpleFeatureValues(
          title: title,
          primary: primary,
          secondary: secondary,
          tertiary: _nginxProjectType,
          description: configPreview,
          status: widget.feature.defaultStatus,
          isEnabled: widget.record?.isEnabled ?? false,
        );
      case 'project':
        return _SimpleFeatureValues(
          title: title,
          primary: _selectedDomain?.trim() ?? primary,
          secondary: secondary,
          tertiary: tertiary.isEmpty ? '-' : tertiary,
          description: description.isEmpty
              ? 'Project hosting $title.'
              : description,
          status: widget.feature.defaultStatus,
          isEnabled: false,
        );
      case 'file_manager':
        return _SimpleFeatureValues(
          title: title,
          primary: primary,
          secondary: _fileManagerType,
          tertiary: _selectedProject?.trim() ?? tertiary,
          description: description.isEmpty
              ? 'Item file manager $title.'
              : description,
          status: widget.feature.defaultStatus,
          isEnabled: false,
        );
      case 'api_monitoring':
        return _SimpleFeatureValues(
          title: title,
          primary: primary,
          secondary: secondary,
          tertiary: tertiary.isEmpty ? '200' : tertiary,
          description: description.isEmpty
              ? 'Monitoring $primary setiap $secondary detik.'
              : description,
          status: widget.feature.defaultStatus,
          isEnabled: true,
        );
      case 'other_services':
        return _SimpleFeatureValues(
          title: title,
          primary: primary,
          secondary: secondary.isEmpty ? 'MySQL' : secondary,
          tertiary: tertiary.isEmpty ? '-' : tertiary,
          description: _backupSettingsDescription(),
          status: widget.feature.defaultStatus,
          isEnabled: false,
        );
      case 'server':
        return _SimpleFeatureValues(
          title: title,
          primary: primary,
          secondary: secondary,
          tertiary: tertiary.isEmpty ? '22' : tertiary,
          description: _serverSettingsDescription(),
          status: widget.feature.defaultStatus,
          isEnabled: false,
        );
      default:
        return _SimpleFeatureValues(
          title: title,
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
          description: description,
          status: widget.feature.defaultStatus,
          isEnabled: widget.feature.showEnabledToggle,
        );
    }
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

  String _serverSettingsDescription() {
    return jsonEncode({
      'password': _serverPasswordController.text.trim(),
      'notes': _descriptionController.text.trim(),
    });
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

  String _backupSettingsDescription() {
    final payload = <String, dynamic>{
      'schedule': _backupScheduleController.text.trim(),
      'target': _backupTargetController.text.trim().isEmpty
          ? '/backups/database'
          : _backupTargetController.text.trim(),
      'retention': _backupRetentionController.text.trim(),
      'notes': _descriptionController.text.trim(),
    };

    try {
      final decoded = jsonDecode(widget.record?.description ?? '');
      if (decoded is Map<String, dynamic> && decoded['results'] is List) {
        payload['results'] = decoded['results'];
      }
    } catch (_) {}

    return jsonEncode(payload);
  }

  Future<void> _pickBackupSchedule() async {
    final initialTime = _timeOfDayFromText(_backupScheduleController.text);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (time == null || !mounted) return;

    setState(() {
      _backupScheduleController.text =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    });
  }

  TimeOfDay _timeOfDayFromText(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts.first);
      final minute = int.tryParse(parts.last);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return const TimeOfDay(hour: 2, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final isNginxEnabledReadOnly =
        widget.feature.key == 'nginx_config' &&
        widget.record?.status.toLowerCase() == 'enabled';

    if (isNginxEnabledReadOnly && widget.record != null) {
      return _buildReadOnlyNginxView(isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record == null
              ? 'Tambah ${widget.feature.title}'
              : 'Edit ${widget.feature.title}',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.feature.accentColor.withOpacity(isDark ? 0.18 : 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.feature.accentColor,
                        widget.feature.accentColor.withOpacity(0.78),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: widget.feature.accentColor.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
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
                        child: Icon(
                          widget.feature.icon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.feature.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.feature.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSubdomainFeature)
                          ..._buildSubdomainFields()
                        else if (_isDomainFeature)
                          ..._buildDomainFields()
                        else
                          ..._buildSimpleFeatureFields(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      widget.record == null ? 'Simpan Data' : 'Perbarui Data',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.feature.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyNginxView(bool isDark) {
    final record = widget.record!;
    final preview = record.description.isNotEmpty
        ? record.description
        : _buildNginxConfigPreview(
            serverName: record.title,
            port: record.primaryValue,
            targetPath: record.secondaryValue,
            projectType: record.tertiaryValue,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Config'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.feature.accentColor.withOpacity(isDark ? 0.18 : 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.feature.accentColor,
                      widget.feature.accentColor.withOpacity(0.78),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.feature.accentColor.withOpacity(0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
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
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Read Only',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Preview config bersifat read only. Ubah file konfigurasi asalnya terlebih dahulu.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail Config',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyRow('Server Name', record.title),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Port', record.primaryValue),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Target Path', record.secondaryValue),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Project', record.tertiaryValue),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Preview Config', preview),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.feature.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Kembali ke Konfigurasi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildNginxConfigPreview({
    required String serverName,
    required String port,
    required String targetPath,
    required String projectType,
  }) {
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

  List<Widget> _buildSimpleFeatureFields() {
    switch (widget.feature.key) {
      case 'nginx_config':
        return [
          _buildField(
            controller: _titleController,
            label: 'Server Name',
            hint: 'app.example.com',
            icon: Icons.language_rounded,
            validatorMessage: 'Server name wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _primaryController,
            label: 'Port',
            hint: '80',
            icon: Icons.settings_ethernet_rounded,
            validatorMessage: 'Port wajib diisi',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _secondaryController,
            label: 'Target Path',
            hint: '/var/www/app/public',
            icon: Icons.folder_rounded,
            validatorMessage: 'Target path wajib diisi',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _nginxProjectType,
            decoration: InputDecoration(
              labelText: 'Project',
              prefixIcon: const Icon(Icons.layers_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: const ['Laravel', 'React', 'Node.js']
                .map(
                  (type) =>
                      DropdownMenuItem<String>(value: type, child: Text(type)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _nginxProjectType = value);
              }
            },
          ),
        ];
      case 'project':
        return [
          _buildField(
            controller: _titleController,
            label: 'Project',
            hint: 'Landing Page',
            icon: Icons.dashboard_customize_rounded,
            validatorMessage: 'Project wajib diisi',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _safeDomainOptions.contains(_selectedDomain)
                ? _selectedDomain
                : null,
            decoration: InputDecoration(
              labelText: 'Domain',
              prefixIcon: const Icon(Icons.public_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: _safeDomainOptions
                .map(
                  (domain) => DropdownMenuItem<String>(
                    value: domain,
                    child: Text(domain),
                  ),
                )
                .toList(),
            onChanged: _safeDomainOptions.isEmpty
                ? null
                : (value) {
                    setState(() => _selectedDomain = value);
                  },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Domain wajib dipilih';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _tertiaryController,
            label: 'Stack',
            hint: 'Flutter / Laravel / Node',
            icon: Icons.layers_rounded,
            validatorMessage: 'Stack wajib diisi',
          ),
        ];
      case 'file_manager':
        return [
          DropdownButtonFormField<String>(
            value: _safeProjectOptions.contains(_selectedProject)
                ? _selectedProject
                : null,
            decoration: InputDecoration(
              labelText: 'Project',
              prefixIcon: const Icon(Icons.dashboard_customize_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: _safeProjectOptions
                .map(
                  (project) => DropdownMenuItem<String>(
                    value: project,
                    child: Text(project),
                  ),
                )
                .toList(),
            onChanged: _safeProjectOptions.isEmpty
                ? null
                : (value) {
                    setState(() => _selectedProject = value);
                  },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Project wajib dipilih';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _titleController,
            label: 'Nama',
            hint: 'public_html',
            icon: Icons.folder_copy_rounded,
            validatorMessage: 'Nama wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _primaryController,
            label: 'Path',
            hint: '/var/www/app/public',
            icon: Icons.folder_rounded,
            validatorMessage: 'Path wajib diisi',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _fileManagerType,
            decoration: InputDecoration(
              labelText: 'Type',
              prefixIcon: const Icon(Icons.insert_drive_file_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: const ['folder', 'file']
                .map(
                  (type) =>
                      DropdownMenuItem<String>(value: type, child: Text(type)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _fileManagerType = value);
              }
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Rename item lewat swipe Edit lalu ubah nama.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
          ),
        ];
      case 'api_monitoring':
        return [
          _buildField(
            controller: _titleController,
            label: 'Nama',
            hint: 'Health Check API',
            icon: Icons.monitor_heart_rounded,
            validatorMessage: 'Nama wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _primaryController,
            label: 'API URL',
            hint: 'https://api.example.com/health',
            icon: Icons.link_rounded,
            validatorMessage: 'API URL wajib diisi',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _secondaryController,
            label: 'Interval (detik)',
            hint: '5',
            icon: Icons.timer_rounded,
            validatorMessage: 'Interval wajib diisi',
            keyboardType: TextInputType.number,
          ),
        ];
      case 'other_services':
        const databaseTypes = [
          'MySQL',
          'PostgreSQL',
          'MongoDB',
          'MariaDB',
          'Redis',
          'SQLite',
        ];
        final selectedDatabase =
            databaseTypes.contains(_secondaryController.text)
            ? _secondaryController.text
            : 'MySQL';
        const retentionOptions = ['Daily', 'Weekly', 'Monthly'];
        final selectedRetention =
            retentionOptions.contains(_backupRetentionController.text)
            ? _backupRetentionController.text
            : 'Daily';

        return [
          _buildField(
            controller: _titleController,
            label: 'Nama Backup',
            hint: 'Backup Production DB',
            icon: Icons.backup_rounded,
            validatorMessage: 'Nama backup wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _primaryController,
            label: 'Host / Database',
            hint: 'localhost/app_db',
            icon: Icons.dns_rounded,
            validatorMessage: 'Host atau database wajib diisi',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedDatabase,
            decoration: InputDecoration(
              labelText: 'Jenis Database',
              prefixIcon: const Icon(Icons.storage_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: databaseTypes
                .map(
                  (type) =>
                      DropdownMenuItem<String>(value: type, child: Text(type)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _secondaryController.text = value);
              }
            },
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _tertiaryController,
            label: 'Port',
            hint: '3306',
            icon: Icons.settings_ethernet_rounded,
            validatorMessage: 'Port wajib diisi',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _backupScheduleController,
            label: 'Jadwal Backup',
            hint: '02:00',
            icon: Icons.event_repeat_rounded,
            validatorMessage: 'Jadwal backup wajib diisi',
            readOnly: true,
            onTap: _pickBackupSchedule,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedRetention,
            decoration: InputDecoration(
              labelText: 'Retention',
              prefixIcon: const Icon(Icons.history_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            items: retentionOptions
                .map(
                  (retention) => DropdownMenuItem<String>(
                    value: retention,
                    child: Text(retention),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _backupRetentionController.text = value);
              }
            },
          ),
        ];
      case 'server':
        return [
          _buildField(
            controller: _titleController,
            label: 'Server',
            hint: 'Node-01',
            icon: Icons.storage_rounded,
            validatorMessage: 'Server wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _primaryController,
            label: 'Host / IP',
            hint: '192.168.1.10',
            icon: Icons.dns_rounded,
            validatorMessage: 'Host / IP wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _tertiaryController,
            label: 'SSH Port',
            hint: '22',
            icon: Icons.settings_ethernet_rounded,
            validatorMessage: 'Port wajib diisi',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _secondaryController,
            label: 'Username SSH',
            hint: 'root',
            icon: Icons.person_rounded,
            validatorMessage: 'Username SSH wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _serverPasswordController,
            label: 'Password SSH',
            hint: 'Password server',
            icon: Icons.lock_rounded,
            validatorMessage: 'Password SSH wajib diisi',
            obscureText: true,
          ),
        ];
      default:
        return [
          _buildField(
            controller: _titleController,
            label: 'Judul',
            hint: 'Nama yang mudah dikenali',
            icon: widget.feature.icon,
            validatorMessage: 'Judul wajib diisi',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _primaryController,
            label: widget.feature.primaryLabel,
            hint: widget.feature.primaryHint,
            icon: Icons.tune_rounded,
            validatorMessage: '${widget.feature.primaryLabel} wajib diisi',
          ),
        ];
    }
  }

  List<Widget> _buildSubdomainFields() {
    return [
      _buildField(
        controller: _primaryController,
        label: 'Subdomain',
        hint: 'dashboard',
        icon: Icons.device_hub_rounded,
        validatorMessage: 'Subdomain wajib diisi',
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _safeDomainOptions.contains(_selectedDomain)
            ? _selectedDomain
            : null,
        decoration: InputDecoration(
          labelText: 'Domain',
          prefixIcon: const Icon(Icons.public_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
        items: _safeDomainOptions
            .map(
              (domain) =>
                  DropdownMenuItem<String>(value: domain, child: Text(domain)),
            )
            .toList(),
        onChanged: _safeDomainOptions.isEmpty
            ? null
            : (value) {
                setState(() => _selectedDomain = value);
              },
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Domain wajib dipilih';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),
      _buildField(
        controller: _tertiaryController,
        label: 'Service',
        hint: 'localhost:80',
        icon: Icons.link_rounded,
        validatorMessage: 'Service wajib diisi',
        keyboardType: TextInputType.url,
      ),
    ];
  }

  List<Widget> _buildDomainFields() {
    return [
      _buildField(
        controller: _titleController,
        label: 'Domain',
        hint: 'example.com',
        icon: Icons.public_rounded,
        validatorMessage: 'Domain wajib diisi',
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 12),
      Text(
        'Nameserver akan dibuat otomatis setelah domain disimpan.',
        style: TextStyle(color: Colors.grey.shade600, height: 1.35),
      ),
    ];
  }

  List<String> _domainNameservers(
    String? currentPrimary,
    String? currentSecondary,
  ) {
    if ((currentPrimary ?? '').trim().isNotEmpty &&
        (currentSecondary ?? '').trim().isNotEmpty) {
      return [currentPrimary!.trim(), currentSecondary!.trim()];
    }

    final domain = _titleController.text.trim().toLowerCase();
    final names = ['ada', 'nina', 'rick', 'josh', 'sara', 'gabe'];
    final hash = domain.codeUnits.fold<int>(0, (sum, code) => sum + code);
    final first = names[hash % names.length];
    final second = names[(hash + 3) % names.length];

    if (first == second) {
      return ['$first.ns.cloudflare.com', 'nina.ns.cloudflare.com'];
    }

    return ['$first.ns.cloudflare.com', '$second.ns.cloudflare.com'];
  }

  Future<void> _showNameserverDialog(HostingRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nameserver Domain'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNameserverCopyRow('Nameserver 1', record.primaryValue),
            const SizedBox(height: 12),
            _buildNameserverCopyRow('Nameserver 2', record.secondaryValue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _buildNameserverCopyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$label disalin')));
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String validatorMessage,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool obscureText = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      obscureText: obscureText,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMessage;
        }
        return null;
      },
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _SimpleFeatureValues {
  final String title;
  final String primary;
  final String secondary;
  final String tertiary;
  final String description;
  final String status;
  final bool isEnabled;

  const _SimpleFeatureValues({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.description,
    required this.status,
    required this.isEnabled,
  });
}
