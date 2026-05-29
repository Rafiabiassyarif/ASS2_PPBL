import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../models/domain_model.dart';
import '../../models/user_model.dart';

class DomainAddPage extends StatefulWidget {
  const DomainAddPage({Key? key}) : super(key: key);

  @override
  State<DomainAddPage> createState() => _DomainAddPageState();
}

class _DomainAddPageState extends State<DomainAddPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final _domainController = TextEditingController();
  int? _selectedClientId;
  DateTime _tanggalDaftar = DateTime.now();
  DateTime _tanggalExpired = DateTime.now().add(const Duration(days: 365));
  String _status = 'aktif';

  List<UserModel> _users = [];
  bool _isLoadingUsers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await _dbHelper.getUsers();
      setState(() {
        _users = list;
        _isLoadingUsers = false;
        if (_users.isNotEmpty) {
          _selectedClientId = _users.first.id;
        }
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clients: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _pickDate(bool isDaftar) async {
    final initialDate = isDaftar ? _tanggalDaftar : _tanggalExpired;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (isDaftar) {
          _tanggalDaftar = picked;
          // Auto adjust expired date if it is before registered date
          if (_tanggalExpired.isBefore(_tanggalDaftar)) {
            _tanggalExpired = _tanggalDaftar.add(const Duration(days: 365));
          }
        } else {
          _tanggalExpired = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedClientId == null) {
      if (_selectedClientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih client terlebih dahulu'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    
    final domain = DomainModel(
      namaDomain: _domainController.text.trim().toLowerCase(),
      clientId: _selectedClientId!,
      tanggalDaftar: DateFormat('yyyy-MM-dd').format(_tanggalDaftar),
      tanggalExpired: DateFormat('yyyy-MM-dd').format(_tanggalExpired),
      status: _status,
    );

    try {
      await _dbHelper.insertDomain(domain);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Domain berhasil ditambahkan'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan domain: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Domain Baru'),
      ),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada client terdaftar.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Silakan tambahkan client baru di menu User Management terlebih dahulu sebelum mendaftarkan domain.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Kembali'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama Domain
                        TextFormField(
                          controller: _domainController,
                          decoration: InputDecoration(
                            labelText: 'Nama Domain',
                            hintText: 'contoh.com',
                            prefixIcon: const Icon(Icons.language),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama domain tidak boleh kosong';
                            }
                            // Basic domain validation regex
                            final domainRegex = RegExp(r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$');
                            if (!domainRegex.hasMatch(value.trim().toLowerCase())) {
                              return 'Format domain tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Dropdown Client
                        DropdownButtonFormField<int>(
                          value: _selectedClientId,
                          decoration: InputDecoration(
                            labelText: 'Pilih Client (User)',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _users.map((user) {
                            return DropdownMenuItem<int>(
                              value: user.id,
                              child: Text('${user.nama} (${user.email})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedClientId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date Pickers row
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(
                                label: 'Tanggal Daftar',
                                date: _tanggalDaftar,
                                onTap: () => _pickDate(true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDatePicker(
                                label: 'Tanggal Expired',
                                date: _tanggalExpired,
                                onTap: () => _pickDate(false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dropdown Status
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            labelText: 'Status Domain',
                            prefixIcon: const Icon(Icons.info_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                            DropdownMenuItem(value: 'expired', child: Text('Expired')),
                            DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _status = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 32),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Simpan Domain', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDatePicker({required String label, required DateTime date, required VoidCallback onTap}) {
    final formatted = DateFormat('dd MMMM yyyy').format(date);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          formatted,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
