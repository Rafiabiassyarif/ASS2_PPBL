import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/preferences/app_preferences.dart';
import '../../models/domain_model.dart';
import '../../models/user_model.dart';
import '../../widgets/donut_status_badge.dart';

class DomainListPage extends StatefulWidget {
  const DomainListPage({Key? key}) : super(key: key);

  @override
  State<DomainListPage> createState() => _DomainListPageState();
}

class _DomainListPageState extends State<DomainListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<DomainModel> _domains = [];
  List<UserModel> _users = []; // To map client_id to client name
  String _statusFilter = 'Semua';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilterPreference();
    _fetchData();
  }

  void _loadFilterPreference() {
    setState(() {
      _statusFilter = AppPreferences.getDomainFilter();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final domains = await _dbHelper.getDomains(
        query: _searchController.text.trim(),
        statusFilter: _statusFilter,
      );
      final users = await _dbHelper.getUsers();
      setState(() {
        _domains = domains;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading domains: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _getClientName(int clientId) {
    final user = _users.firstWhere((u) => u.id == clientId,
        orElse: () => UserModel(id: -1, nama: 'Unknown', email: '', paketId: -1, status: '', tanggalDaftar: ''));
    return user.nama;
  }

  double _hitungPersentaseSisa(String tglDaftar, String tglExpired) {
    try {
      final daftar = DateTime.parse(tglDaftar);
      final expired = DateTime.parse(tglExpired);
      final total = expired.difference(daftar).inDays;
      if (total <= 0) return 0.0;
      final sisa = expired.difference(DateTime.now()).inDays;
      if (sisa <= 0) return 0.0;
      return (sisa / total).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  int _hitungSisaHari(String tglExpired) {
    try {
      final expired = DateTime.parse(tglExpired);
      final sisa = expired.difference(DateTime.now()).inDays;
      return sisa < 0 ? 0 : sisa;
    } catch (_) {
      return 0;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aktif':
        return Colors.green.shade600;
      case 'expired':
        return Colors.red.shade600;
      case 'suspended':
        return Colors.orange.shade700;
      default:
        return Colors.grey;
    }
  }

  Future<void> _deleteDomain(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Domain'),
        content: const Text('Apakah Anda yakin ingin menghapus domain ini secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteDomain(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Domain berhasil dihapus'), backgroundColor: Colors.green),
      );
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/domains/add');
              if (result == true) _fetchData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari domain...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchData();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) => _fetchData(),
            ),
          ),

          // Chips Status Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Semua', 'Aktif', 'Expired', 'Suspended'].map((status) {
                final isSelected = _statusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    selectedColor: Colors.teal.withOpacity(0.2),
                    checkmarkColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.teal : (isDark ? Colors.white : Colors.black),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (bool selected) async {
                      if (selected) {
                        setState(() {
                          _statusFilter = status;
                        });
                        await AppPreferences.setDomainFilter(status);
                        _fetchData();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // List content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : _domains.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dns_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada domain ditemukan',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        color: Colors.teal,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _domains.length,
                          itemBuilder: (context, index) {
                            final domain = _domains[index];
                            final percentage = _hitungPersentaseSisa(domain.tanggalDaftar, domain.tanggalExpired);
                            final sisaHari = _hitungSisaHari(domain.tanggalExpired);
                            final statusColor = _getStatusColor(domain.status);
                            final formattedExp = DateFormat('dd MMM yyyy')
                                .format(DateTime.parse(domain.tanggalExpired));

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Slidable(
                                  key: ValueKey(domain.id),
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    children: [
                                      SlidableAction(
                                        onPressed: (context) async {
                                          final result = await Navigator.pushNamed(
                                            context,
                                            '/domains/edit',
                                            arguments: domain,
                                          );
                                          if (result == true) _fetchData();
                                        },
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                        icon: Icons.edit,
                                        label: 'Edit',
                                      ),
                                      SlidableAction(
                                        onPressed: (context) {
                                          if (domain.id != null) {
                                            _deleteDomain(domain.id!);
                                          }
                                        },
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                        icon: Icons.delete,
                                        label: 'Hapus',
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Custom DonutStatusBadge
                                        DonutStatusBadge(
                                          percentage: percentage,
                                          color: statusColor,
                                          centerText: '${sisaHari}h',
                                        ),
                                        const SizedBox(width: 16),
                                        // Domain info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                domain.namaDomain,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Client: ${_getClientName(domain.clientId)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today_outlined,
                                                      size: 12, color: Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Exp: $formattedExp',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Status Chip
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            domain.status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
