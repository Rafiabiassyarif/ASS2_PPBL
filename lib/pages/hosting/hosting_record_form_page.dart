import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../models/hosting_record_model.dart';
import 'hosting_feature_spec.dart';

class HostingRecordFormPage extends StatefulWidget {
  final HostingFeatureSpec feature;
  final HostingRecord? record;

  const HostingRecordFormPage({super.key, required this.feature, this.record});

  @override
  State<HostingRecordFormPage> createState() => _HostingRecordFormPageState();
}

class _HostingRecordFormPageState extends State<HostingRecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _tertiaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late String _status;
  late bool _isEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _titleController.text = record?.title ?? '';
    _primaryController.text = record?.primaryValue ?? '';
    _secondaryController.text = record?.secondaryValue ?? '';
    _tertiaryController.text = record?.tertiaryValue ?? '';
    _descriptionController.text = record?.description ?? '';
    _status = record?.status ?? widget.feature.defaultStatus;
    _isEnabled = record?.isEnabled ?? widget.feature.showEnabledToggle;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    _tertiaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    final previous = widget.record;

    final record = HostingRecord(
      id: previous?.id,
      featureKey: widget.feature.key,
      title: _titleController.text.trim(),
      primaryValue: _primaryController.text.trim(),
      secondaryValue: _secondaryController.text.trim(),
      tertiaryValue: _tertiaryController.text.trim(),
      description: _descriptionController.text.trim(),
      status: _status,
      isEnabled: _isEnabled,
      createdAt: previous?.createdAt.isNotEmpty == true
          ? previous!.createdAt
          : now,
      updatedAt: now,
    );

    try {
      if (previous == null) {
        await _dbHelper.insertHostingRecord(record);
      } else {
        await _dbHelper.updateHostingRecord(record);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.feature.title} berhasil disimpan'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan ${widget.feature.title.toLowerCase()}: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final isNginxEnabledReadOnly =
        widget.feature.key == 'nginx_config' &&
        widget.record?.status.toLowerCase() == 'enabled';

    if (isNginxEnabledReadOnly && widget.record != null) {
      return _buildReadOnlyNginxView(isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record == null
              ? 'Tambah ${widget.feature.title}'
              : 'Edit ${widget.feature.title}',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.feature.accentColor.withOpacity(isDark ? 0.18 : 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.feature.accentColor,
                        widget.feature.accentColor.withOpacity(0.78),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: widget.feature.accentColor.withOpacity(0.25),
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
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.feature.icon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.feature.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.feature.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: _titleController,
                          label: 'Judul',
                          hint: 'Nama yang mudah dikenali',
                          icon: widget.feature.icon,
                          validatorMessage: 'Judul tidak boleh kosong',
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _primaryController,
                          label: widget.feature.primaryLabel,
                          hint: widget.feature.primaryHint,
                          icon: Icons.tune_rounded,
                          validatorMessage:
                              '${widget.feature.primaryLabel} wajib diisi',
                          keyboardType:
                              widget.feature.key == 'api_monitoring' ||
                                  widget.feature.key == 'server'
                              ? TextInputType.url
                              : TextInputType.text,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _secondaryController,
                          label: widget.feature.secondaryLabel,
                          hint: widget.feature.secondaryHint,
                          icon: Icons.link_rounded,
                          validatorMessage:
                              '${widget.feature.secondaryLabel} wajib diisi',
                          keyboardType: widget.feature.key == 'api_monitoring'
                              ? TextInputType.number
                              : TextInputType.text,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _tertiaryController,
                          label: widget.feature.tertiaryLabel,
                          hint: widget.feature.tertiaryHint,
                          icon: Icons.more_horiz_rounded,
                          validatorMessage:
                              '${widget.feature.tertiaryLabel} wajib diisi',
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _descriptionController,
                          label: widget.feature.descriptionLabel,
                          hint: widget.feature.descriptionHint,
                          icon: Icons.notes_rounded,
                          validatorMessage:
                              '${widget.feature.descriptionLabel} wajib diisi',
                          maxLines: widget.feature.descriptionLines,
                        ),
                        const SizedBox(height: 14),
                        if (widget.feature.statusOptions.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              prefixIcon: const Icon(Icons.flag_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            items: widget.feature.statusOptions
                                .map(
                                  (status) => DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                          ),
                        if (widget.feature.statusOptions.isNotEmpty)
                          const SizedBox(height: 14),
                        if (widget.feature.showEnabledToggle)
                          SwitchListTile(
                            value: _isEnabled,
                            onChanged: (value) =>
                                setState(() => _isEnabled = value),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enabled'),
                            subtitle: const Text('Aktifkan item ini di panel'),
                            secondary: Icon(
                              _isEnabled
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_rounded,
                              color: widget.feature.accentColor,
                              size: 32,
                            ),
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
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      widget.record == null ? 'Simpan Data' : 'Perbarui Data',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.feature.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

  Widget _buildReadOnlyNginxView(bool isDark) {
    final record = widget.record!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites Enabled'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.feature.accentColor.withOpacity(isDark ? 0.18 : 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.feature.accentColor,
                      widget.feature.accentColor.withOpacity(0.78),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.feature.accentColor.withOpacity(0.25),
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
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
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
                            'Read Only',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Config yang sudah aktif di sites-enabled tidak bisa diedit langsung. Ubah file asalnya di sites-available.',
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
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Info Config Aktif',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyRow('Judul', record.title),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Path', record.primaryValue),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Server Name', record.secondaryValue),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Target', record.tertiaryValue),
                      const SizedBox(height: 12),
                      _buildReadOnlyRow('Block', record.description),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.feature.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Kembali ke Sites Available'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String validatorMessage,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMessage;
        }
        return null;
      },
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(height: 1.35),
          ),
        ),
      ],
    );
  }
}
