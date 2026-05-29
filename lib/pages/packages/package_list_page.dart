import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/preferences/app_preferences.dart';
import '../../models/package_model.dart';
import '../../widgets/drag_rank_tile.dart';

class PackageListPage extends StatefulWidget {
  const PackageListPage({Key? key}) : super(key: key);

  @override
  State<PackageListPage> createState() => _PackageListPageState();
}

class _PackageListPageState extends State<PackageListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<PackageModel> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    setState(() => _isLoading = true);
    try {
      final dbList = await _dbHelper.getPackages();

      // Read package order from preferences
      final orderJson = AppPreferences.getPackageOrder();
      List<dynamic> savedIds = [];
      try {
        savedIds = jsonDecode(orderJson);
      } catch (_) {}

      if (savedIds.isNotEmpty) {
        final idMap = {for (var item in savedIds) item.toString(): savedIds.indexOf(item)};
        dbList.sort((a, b) {
          final indexA = idMap[a.id.toString()] ?? 9999;
          final indexB = idMap[b.id.toString()] ?? 9999;
          return indexA.compareTo(indexB);
        });
      }

      setState(() {
        _packages = dbList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading packages: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    
    setState(() {
      final item = _packages.removeAt(oldIndex);
      _packages.insert(newIndex, item);
    });

    // Save the new order to SharedPreferences
    final ids = _packages.map((p) => p.id.toString()).toList();
    await AppPreferences.setPackageOrder(jsonEncode(ids));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Urutan paket hosting berhasil diperbarui'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deletePackage(PackageModel pkg) async {
    final count = pkg.jumlahUser ?? 0;
    
    if (count > 0) {
      // Reject deletion
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gagal Menghapus'),
          content: Text(
            'Paket "${pkg.namaPaket}" sedang digunakan oleh $count client.\n\nAnda tidak dapat menghapus paket ini sebelum memindahkan client ke paket lain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Apakah Anda yakin ingin menghapus paket "${pkg.namaPaket}"?'),
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

    if (confirm == true && pkg.id != null) {
      try {
        await _dbHelper.deletePackage(pkg.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paket hosting berhasil dihapus'), backgroundColor: Colors.green),
        );
        _fetchPackages();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus paket: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packages Management', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/packages/add');
          if (result == true) _fetchPackages();
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _packages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_clear_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada paket hosting terdaftar',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            'Tekan lama dan seret (drag) tile untuk mengubah urutan prioritas.',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchPackages,
                        color: Colors.teal,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: _packages.length,
                          itemBuilder: (context, index) {
                            final pkg = _packages[index];
                            return DragRankTile(
                              package: pkg,
                              index: index,
                              onReorder: _onReorder,
                              onTap: () async {
                                final result = await Navigator.pushNamed(
                                  context,
                                  '/packages/edit',
                                  arguments: pkg,
                                );
                                if (result == true) _fetchPackages();
                              },
                              onDelete: () => _deletePackage(pkg),
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
