part of 'hosting_crud_page.dart';

extension _HostingCrudSubdomain on _HostingCrudPageState {
  Widget _buildSubdomainContent() {
    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(_feature.icon, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada data ${_feature.title.toLowerCase()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan subdomain dan hostname internal yang ingin diarahkan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Slidable(
            key: ValueKey(record.id ?? '${record.featureKey}-$index'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _openForm(record: record),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                ),
                SlidableAction(
                  onPressed: (_) => _deleteRecord(record),
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'Hapus',
                ),
              ],
            ),
            child: _buildSubdomainRecordCard(record),
          ),
        );
      },
    );
  }

  Widget _buildSubdomainRecordCard(HostingRecord record) {
    final titleParts = record.title.split('.');
    final domainFromTitle = titleParts.length > 1
        ? titleParts.skip(1).join('.')
        : '';
    final serviceText = record.tertiaryValue.startsWith('proxy://')
        ? record.primaryValue
        : record.tertiaryValue.isEmpty
        ? _feature.tertiaryHint
        : record.tertiaryValue;
    final domainText = record.secondaryValue.contains('.')
        ? record.secondaryValue
        : domainFromTitle.isNotEmpty
        ? domainFromTitle
        : record.secondaryValue.isEmpty
        ? _feature.secondaryHint
        : record.secondaryValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _feature.accentColor.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _feature.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_feature.icon, color: _feature.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$domainText -> $serviceText',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _statusLabel(record.status),
                style: TextStyle(
                  color: _statusColor(record.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
