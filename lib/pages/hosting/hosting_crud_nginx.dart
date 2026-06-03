part of 'hosting_crud_page.dart';

extension _HostingCrudNginx on _HostingCrudPageState {
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
                  _safeSetState(() {
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
                  _safeSetState(() {
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
}
