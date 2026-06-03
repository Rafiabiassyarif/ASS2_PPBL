part of 'hosting_crud_page.dart';

extension _HostingCrudProject on _HostingCrudPageState {
  Widget _buildProjectRecordCard(HostingRecord record) {
    final domain = record.primaryValue.isEmpty ? '-' : record.primaryValue;
    final repository = record.secondaryValue.isEmpty
        ? '-'
        : record.secondaryValue;
    final stack = record.tertiaryValue.isEmpty ? '-' : record.tertiaryValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.circle_rounded,
                    color: _statusColor(record.status),
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildProjectInfoRow(Icons.public_rounded, domain),
              const SizedBox(height: 8),
              _buildProjectInfoRow(Icons.layers_rounded, stack),
              if (repository != '-') ...[
                const SizedBox(height: 8),
                _buildProjectInfoRow(Icons.code_rounded, repository),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _feature.accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
