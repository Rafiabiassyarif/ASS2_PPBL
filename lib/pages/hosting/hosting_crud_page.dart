import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _records.length;
    final enabledCount = _records.where((record) => record.isEnabled).length;
    final statusCount = _records.map((record) => record.status).toSet().length;
    final nginxWarehouseCount = _nginxWarehouseRecords.length;
    final nginxEnabledCount = _nginxEnabledRecords.length;

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
                  ? _buildNginxHeroCard(
                      total,
                      nginxWarehouseCount,
                      nginxEnabledCount,
                    )
                  : _buildHeroCard(total, enabledCount, statusCount),
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
            if (_isFileManagerConfig)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildFileManagerProjectFilter(),
              ),
            if (_isNginxConfig) const SizedBox(height: 12),
            if (_isFileManagerConfig) const SizedBox(height: 12),
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
                if (_feature.showEnabledToggle && !_isNginxConfig)
                  SlidableAction(
                    onPressed: (_) => _toggleEnabled(record),
                    backgroundColor: record.isEnabled
                        ? Colors.orange.shade700
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    icon: record.isEnabled
                        ? Icons.toggle_off_rounded
                        : Icons.toggle_on_rounded,
                    label: record.isEnabled ? 'Disable' : 'Enable',
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
                : _buildRecordCard(record),
          ),
        );
      },
    );
  }

  Widget _buildFileManagerProjectFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedFileManagerProject,
      decoration: InputDecoration(
        labelText: 'Project',
        prefixIcon: const Icon(Icons.dashboard_customize_rounded),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      items: _fileManagerProjectItems()
          .map(
            (project) =>
                DropdownMenuItem<String>(value: project, child: Text(project)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedFileManagerProject = value;
            _fileManagerPath = '/';
          });
        }
      },
    );
  }

  List<String> _fileManagerProjectItems() {
    return <String>['Semua', ..._safeFileManagerProjects];
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
          _buildFileManagerToolbar(
            total: projects.length,
            folderCount: projects.length,
            fileCount: 0,
            allProjectItems: projectRecords.length,
          ),
          const SizedBox(height: 12),
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
        ? '/projects'
        : '/projects/$project$_fileManagerPath';
    final canGoBack = _fileManagerPath != '/';

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
                      _fileManagerPath = _parentPath(_fileManagerPath);
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
          if (project != 'Semua' && allProjectItems != total) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$allProjectItems item di project ini',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ),
          ],
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
    final itemCount = _records
        .where((record) => record.tertiaryValue == project)
        .length;

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
                    const SizedBox(height: 4),
                    Text(
                      '$itemCount item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
            'Tambahkan file config ke sites-available, lalu aktifkan ke sites-enabled saat siap dipakai.',
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sites Available',
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sites Enabled',
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

  Widget _buildHeroCard(int total, int enabledCount, int statusCount) {
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
                  total == 0 ? 'Siap diisi' : '$total item aktif di panel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroPill(
                      'Enabled $enabledCount',
                      Icons.toggle_on_rounded,
                    ),
                    _buildHeroPill('Status $statusCount', Icons.flag_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNginxHeroCard(int total, int availableCount, int enabledCount) {
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
                  total == 0 ? 'Siap diisi' : '$total config tersedia',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroPill(
                      'Available $availableCount',
                      Icons.edit_rounded,
                    ),
                    _buildHeroPill(
                      'Enabled $enabledCount',
                      Icons.toggle_on_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
                record.status,
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
    final statusColor = isEnabled
        ? Colors.green.shade700
        : Colors.orange.shade700;
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
                  const SizedBox(width: 12),
                  Text(
                    isEnabled ? 'Enabled' : 'Available',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
    final rows = _simpleRecordRows(record);

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
        return [
          _RecordInfoRow('URL', record.primaryValue),
          _RecordInfoRow('Interval', '${record.secondaryValue} detik'),
        ];
      case 'other_services':
        return [
          _RecordInfoRow('Link', record.primaryValue),
          _RecordInfoRow('Deskripsi', record.description),
        ];
      case 'server':
        return [
          _RecordInfoRow('Host', record.primaryValue),
          _RecordInfoRow('Port', record.tertiaryValue),
        ];
      default:
        return [
          _RecordInfoRow(widget.feature.primaryLabel, record.primaryValue),
          _RecordInfoRow(widget.feature.secondaryLabel, record.secondaryValue),
        ];
    }
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
        return Colors.green.shade700;
      case 'paused':
      case 'maintenance':
      case 'degraded':
      case 'draft':
      case 'planning':
      case 'review':
        return Colors.orange.shade700;
      case 'disabled':
      case 'expired':
      case 'down':
      case 'offline':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }
}

class _RecordInfoRow {
  final String label;
  final String value;

  const _RecordInfoRow(this.label, this.value);
}
