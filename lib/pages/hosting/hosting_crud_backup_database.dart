part of 'hosting_crud_page.dart';

extension _HostingCrudBackupDatabase on _HostingCrudPageState {
  Future<void> _runBackupDatabase(HostingRecord record) async {
    final id = record.id;
    if (id == null || _runningBackupRecordIds.contains(id)) return;

    final runningAt = DateTime.now().toIso8601String();
    _safeSetState(() {
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
      _safeSetState(() {
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
        _safeSetState(() {
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
}
