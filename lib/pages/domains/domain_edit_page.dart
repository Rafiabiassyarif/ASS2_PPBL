import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../models/domain_model.dart';
import '../../models/user_model.dart';

class DomainEditPage extends StatefulWidget {
  const DomainEditPage({Key? key}) : super(key: key);

  @override
  State<DomainEditPage> createState() => _DomainEditPageState();
}

class _DomainEditPageState extends State<DomainEditPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late DomainModel _domain;
  bool _isInit = false;

  final _domainController = TextEditingController();
  int? _selectedClientId;
  DateTime _tanggalDaftar = DateTime.now();
  DateTime _tanggalExpired = DateTime.now();
  String _status = 'aktif';

  List<UserModel> _users = [];
  bool _isLoadingUsers = true;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      // Get DomainModel from navigation arguments
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is DomainModel) {
        _domain = arg;
        _domainController.text = _domain.namaDomain;
        _selectedClientId = _domain.clientId;
        _tanggalDaftar = DateTime.parse(_domain.tanggalDaftar);
        _tanggalExpired = DateTime.parse(_domain.tanggalExpired);
        _status = _domain.status;
      }
      _loadUsers();
      _isInit = true;
    }
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
    if (!_formKey.currentState!.validate() || _selectedClientId == null) return;

    setState(() => _isSaving = true);

    final updatedDomain = _domain.copyWith(
      namaDomain: _domainController.text.trim().toLowerCase(),
      clientId: _selectedClientId!,
      tanggalDaftar: DateFormat('yyyy-MM-dd').format(_tanggalDaftar),
      tanggalExpired: DateFormat('yyyy-MM-dd').format(_tanggalExpired),
      status: _status,
    );

    try {
      await _dbHelper.updateDomain(updatedDomain);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Domain berhasil diperbarui'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui domain: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Domain'),
      ),
      body: _isLoadingUsers
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Domain Name
                    TextFormField(
                      controller: _domainController,
                      decoration: InputDecoration(
                        labelText: 'Nama Domain',
                        prefixIcon: const Icon(Icons.language),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama domain tidak boleh kosong';
                        }
                        final domainRegex = RegExp(r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$');
                        if (!domainRegex.hasMatch(value.trim().toLowerCase())) {
                          return 'Format domain tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Client Selection
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

                    // Date range
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

                    // Status Dropdown
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

                    // Submit Button
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
                            : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
