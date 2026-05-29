import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../models/ticket_model.dart';
import '../../models/user_model.dart';

class TicketAddPage extends StatefulWidget {
  const TicketAddPage({Key? key}) : super(key: key);

  @override
  State<TicketAddPage> createState() => _TicketAddPageState();
}

class _TicketAddPageState extends State<TicketAddPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final _subjekController = TextEditingController();
  final _pesanController = TextEditingController();
  int? _selectedUserId;
  String _prioritas = 'medium';

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
    _subjekController.dispose();
    _pesanController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await _dbHelper.getUsers();
      setState(() {
        _users = list;
        _isLoadingUsers = false;
        if (_users.isNotEmpty) {
          _selectedUserId = _users.first.id;
        }
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clients: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedUserId == null) {
      if (_selectedUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih client terlebih dahulu'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final nowStr = DateTime.now().toString();
    final ticket = TicketModel(
      userId: _selectedUserId!,
      subjek: _subjekController.text.trim(),
      pesan: _pesanController.text.trim(),
      status: 'open',
      prioritas: _prioritas,
      tanggalBuat: nowStr,
      tanggalUpdate: nowStr,
    );

    try {
      await _dbHelper.insertTicket(ticket);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiket berhasil disimulasikan dari client'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan tiket: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulasi Tiket Client'),
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
                          'Silakan tambahkan client baru di menu User Management terlebih dahulu sebelum membuat simulasi tiket.',
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
                        const Text(
                          'Simulasi Tiket Masuk',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Simulasikan pesan kendala / keluhan yang dikirimkan oleh client ke tim admin hosting.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // Dropdown Client
                        DropdownButtonFormField<int>(
                          value: _selectedUserId,
                          decoration: InputDecoration(
                            labelText: 'Pilih Pengirim (Client)',
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
                              _selectedUserId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Subjek
                        TextFormField(
                          controller: _subjekController,
                          decoration: InputDecoration(
                            labelText: 'Subjek / Judul Tiket',
                            prefixIcon: const Icon(Icons.subject),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Subjek tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Prioritas Dropdown
                        DropdownButtonFormField<String>(
                          value: _prioritas,
                          decoration: InputDecoration(
                            labelText: 'Prioritas Tiket',
                            prefixIcon: const Icon(Icons.priority_high),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low (Rendah)')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium (Sedang)')),
                            DropdownMenuItem(value: 'high', child: Text('High (Tinggi)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _prioritas = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Pesan
                        TextFormField(
                          controller: _pesanController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Pesan / Masalah Client',
                            prefixIcon: const Icon(Icons.chat_bubble_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Pesan tidak boleh kosong';
                            }
                            return null;
                          },
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
                                : const Text('Kirim Tiket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
