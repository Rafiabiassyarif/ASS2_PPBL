part of 'hosting_crud_page.dart';

extension _HostingCrudMonitoring on _HostingCrudPageState {
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

    _safeSetState(() {
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
        _safeSetState(() {
          _runningApiRecordIds.remove(id);
          _testingApiRecordIds.remove(id);
          _apiLatencyMsById[id] = stopwatch.elapsedMilliseconds;
          _apiLastCheckedById[id] = checkedAt;
        });
      }
    }

    if (!mounted) return;
    _safeSetState(() {
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

    _safeSetState(() => _testingServerRecordIds.add(id));

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
        _safeSetState(() {
          _testingServerRecordIds.remove(id);
          _serverLatencyMsById[id] = stopwatch.elapsedMilliseconds;
          _serverLastCheckedById[id] = checkedAt;
        });
      }
    }

    if (!mounted) return;
    _safeSetState(() {
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
}

class _ServerEndpoint {
  final String host;
  final int port;

  const _ServerEndpoint({required this.host, required this.port});
}
