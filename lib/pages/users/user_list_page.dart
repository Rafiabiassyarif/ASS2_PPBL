import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../models/user_model.dart';
import '../../widgets/swipe_reveal_tile.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({Key? key}) : super(key: key);

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dbHelper.getUsers();
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleSuspend(UserModel user) async {
    final newStatus = user.status.toLowerCase() == 'suspended' ? 'aktif' : 'suspended';
    final updated = user.copyWith(status: newStatus);

    try {
      await _dbHelper.updateUser(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${user.nama} berhasil di-${newStatus == 'aktif' ? 'aktifkan' : 'suspend'}'),
          backgroundColor: newStatus == 'aktif' ? Colors.green : Colors.orange.shade700,
        ),
      );
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui status user: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    // Check if user has active domains first (optional warning)
    final allDomains = await _dbHelper.getDomains();
    final userDomains = allDomains.where((d) => d.clientId == user.id).toList();

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin menghapus client "${user.nama}" secara permanen?'),
            if (userDomains.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'PERINGATAN: Menghapus client ini juga akan menghapus ${userDomains.length} domain terkait.',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ]
          ],
        ),
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

    if (confirm == true && user.id != null) {
      try {
        await _dbHelper.deleteUser(user.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client berhasil dihapus'), backgroundColor: Colors.green),
          );
          _fetchUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus client: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/users/add');
          if (result == true) _fetchUsers();
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada client terdaftar',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchUsers,
                  color: Colors.teal,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return SwipeRevealTile(
                        nama: user.nama,
                        email: user.email,
                        status: user.status,
                        packageName: user.namaPaket ?? 'Tanpa Paket',
                        onEdit: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/users/edit',
                            arguments: user,
                          );
                          if (result == true) _fetchUsers();
                        },
                        onSuspend: () => _toggleSuspend(user),
                        onDelete: () => _deleteUser(user),
                      );
                    },
                  ),
                ),
    );
  }
}
