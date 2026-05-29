import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../models/ticket_model.dart';

class TicketDetailPage extends StatefulWidget {
  const TicketDetailPage({Key? key}) : super(key: key);

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late TicketModel _ticket;
  bool _isInit = false;

  final _replyController = TextEditingController();
  String _status = 'open';
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is TicketModel) {
        _ticket = arg;
        _status = _ticket.status;
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // If there is an admin reply, we append it to the ticket messages (or simulate sending)
    String updatedMessage = _ticket.pesan;
    if (_replyController.text.trim().isNotEmpty) {
      updatedMessage += '\n\n--- Balasan Admin (${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}) ---\n${_replyController.text.trim()}';
    }

    final updatedTicket = _ticket.copyWith(
      status: _status,
      pesan: updatedMessage,
      tanggalUpdate: DateTime.now().toString(),
    );

    try {
      await _dbHelper.updateTicket(updatedTicket);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiket berhasil diperbarui & balasan terkirim'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui tiket: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(_ticket.prioritas);
    
    DateTime? createdDate;
    String formattedCreated = _ticket.tanggalBuat;
    try {
      createdDate = DateTime.parse(_ticket.tanggalBuat);
      formattedCreated = DateFormat('dd MMMM yyyy, HH:mm').format(createdDate);
    } catch (_) {}

    DateTime? updatedDate;
    String formattedUpdated = _ticket.tanggalUpdate;
    try {
      updatedDate = DateTime.parse(_ticket.tanggalUpdate);
      formattedUpdated = DateFormat('dd MMMM yyyy, HH:mm').format(updatedDate);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tiket Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ticket Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _ticket.subjek,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: priorityColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              _ticket.prioritas.toUpperCase(),
                              style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(Icons.person, 'Pengirim', _ticket.namaUser ?? 'Unknown'),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.calendar_today, 'Dibuat', formattedCreated),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.sync_alt, 'Terakhir Diperbarui', formattedUpdated),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Message Section
              const Text(
                'Pesan Masalah',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                ),
                child: Text(
                  _ticket.pesan,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),

              // Admin controls
              const Text(
                'Tindakan Admin',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 12),

              // Change status dropdown
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  labelText: 'Status Tiket',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open (Belum Diproses)')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress (Sedang Diproses)')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed (Selesai)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _status = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Reply Text field
              TextFormField(
                controller: _replyController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Tulis Balasan / Catatan Admin',
                  prefixIcon: const Icon(Icons.reply),
                  hintText: 'Tulis respon penyelesaian kendala di sini...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  // Optional reply, but if they change status to Closed it's nice to prompt a resolution note.
                  return null;
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
                      : const Text('Simpan & Kirim Balasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
