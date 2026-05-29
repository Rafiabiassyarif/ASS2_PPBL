import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../models/package_model.dart';

class PackageAddPage extends StatefulWidget {
  const PackageAddPage({Key? key}) : super(key: key);

  @override
  State<PackageAddPage> createState() => _PackageAddPageState();
}

class _PackageAddPageState extends State<PackageAddPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final _namaController = TextEditingController();
  final _hargaController = TextEditingController();
  final _kuotaController = TextEditingController();
  final _domainController = TextEditingController();
  final _deskripsiController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    _kuotaController.dispose();
    _domainController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final package = PackageModel(
      namaPaket: _namaController.text.trim(),
      harga: int.parse(_hargaController.text.trim()),
      kuotaDisk: int.parse(_kuotaController.text.trim()),
      maxDomain: int.parse(_domainController.text.trim()),
      deskripsi: _deskripsiController.text.trim().isEmpty ? null : _deskripsiController.text.trim(),
    );

    try {
      await _dbHelper.insertPackage(package);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paket hosting berhasil ditambahkan'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan paket: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Paket Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Paket
              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Paket Hosting',
                  prefixIcon: const Icon(Icons.layers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama paket tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Harga
              TextFormField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Harga Paket (Rupiah)',
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixText: 'Rupiah',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Harga tidak boleh kosong';
                  }
                  final val = int.tryParse(value.trim());
                  if (val == null || val <= 0) {
                    return 'Harga harus berupa angka positif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kuota Disk & Max Domain row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kuotaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Kuota Disk (GB)',
                        prefixIcon: const Icon(Icons.storage),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Kuota disk wajib diisi';
                        }
                        final val = int.tryParse(value.trim());
                        if (val == null || val <= 0) {
                          return 'Kuota harus angka positif';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _domainController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Batas Max Domain',
                        prefixIcon: const Icon(Icons.language),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Batas domain wajib diisi';
                        }
                        final val = int.tryParse(value.trim());
                        if (val == null || val <= 0) {
                          return 'Batas harus angka positif';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Paket',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
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
                      : const Text('Simpan Paket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
