import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../models/user_model.dart';
import '../../models/package_model.dart';

class UserEditPage extends StatefulWidget {
  const UserEditPage({Key? key}) : super(key: key);

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late UserModel _user;
  bool _isInit = false;

  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  int? _selectedPackageId;
  String _status = 'aktif';

  List<PackageModel> _packages = [];
  bool _isLoadingPackages = true;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is UserModel) {
        _user = arg;
        _namaController.text = _user.nama;
        _emailController.text = _user.email;
        _selectedPackageId = _user.paketId;
        _status = _user.status;
      }
      _loadPackages();
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    try {
      final list = await _dbHelper.getPackages();
      setState(() {
        _packages = list;
        _isLoadingPackages = false;
      });
    } catch (e) {
      setState(() => _isLoadingPackages = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading packages: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedPackageId == null) return;

    setState(() => _isSaving = true);

    final updatedUser = _user.copyWith(
      nama: _namaController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      paketId: _selectedPackageId!,
      status: _status,
    );

    try {
      await _dbHelper.updateUser(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data client berhasil diperbarui'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('UNIQUE') 
                ? 'Email sudah terdaftar. Silakan gunakan email lain.' 
                : 'Gagal memperbarui client: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Client'),
      ),
      body: _isLoadingPackages
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama
                    TextFormField(
                      controller: _namaController,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Alamat Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dropdown Paket
                    DropdownButtonFormField<int>(
                      value: _selectedPackageId,
                      decoration: InputDecoration(
                        labelText: 'Paket Hosting',
                        prefixIcon: const Icon(Icons.layers),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _packages.map((pkg) {
                        return DropdownMenuItem<int>(
                          value: pkg.id,
                          child: Text(pkg.namaPaket),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPackageId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dropdown Status
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: 'Status Akun',
                        prefixIcon: const Icon(Icons.info_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
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
                            : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
