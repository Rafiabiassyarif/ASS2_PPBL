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
        SnackBar(
          content: Text('Error loading clients: $e'),
          backgroundColor: Colors.redAccent,
        ),
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
          const SnackBar(
            content: Text('Domain berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui domain: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Domain'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.withOpacity(isDark ? 0.16 : 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: _isLoadingUsers
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.22),
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
                                color: Colors.white.withOpacity(0.16),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.language_rounded,
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
                                    'Perbarui Domain',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ubah client, status, dan tanggal domain dengan tampilan yang lebih nyaman dibaca.',
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
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informasi Domain',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _domainController,
                                decoration: InputDecoration(
                                  labelText: 'Nama Domain',
                                  prefixIcon: const Icon(Icons.language),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nama domain tidak boleh kosong';
                                  }
                                  final domainRegex = RegExp(
                                    r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$',
                                  );
                                  if (!domainRegex.hasMatch(
                                    value.trim().toLowerCase(),
                                  )) {
                                    return 'Format domain tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: _selectedClientId,
                                decoration: InputDecoration(
                                  labelText: 'Pilih Client (User)',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
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
                              DropdownButtonFormField<String>(
                                value: _status,
                                decoration: InputDecoration(
                                  labelText: 'Status Domain',
                                  prefixIcon: const Icon(Icons.info_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'aktif',
                                    child: Text('Aktif'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'expired',
                                    child: Text('Expired'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'suspended',
                                    child: Text('Suspended'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _status = val;
                                    });
                                  }
                                },
                              ),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
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
        child: Text(formatted, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
