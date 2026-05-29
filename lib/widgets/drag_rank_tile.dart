import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/package_model.dart';

class DragRankTile extends StatelessWidget {
  final PackageModel package;
  final int index;
  final Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DragRankTile({
    Key? key,
    required this.package,
    required this.index,
    required this.onReorder,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DragTarget<int>(
      onWillAccept: (data) => data != null && data != index,
      onAccept: (oldIndex) {
        onReorder(oldIndex, index);
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isOver
                ? (isDark ? Colors.blueGrey[900] : Colors.blue[50])
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: LongPressDraggable<int>(
            data: index,
            maxSimultaneousDrags: 1,
            feedback: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                child: _buildTileContent(context, isDragging: true),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: _buildTileContent(context),
            ),
            child: _buildTileContent(context),
          ),
        );
      },
    );
  }

  Widget _buildTileContent(BuildContext context, {bool isDragging = false}) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDragging
              ? Colors.teal.shade400
              : (isDark ? Colors.grey[850]! : Colors.grey[200]!),
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: ListTile(
        onTap: isDragging ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.layers, color: Colors.teal),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                package.namaPaket,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              currencyFormat.format(package.harga),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
                fontSize: 14,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                package.deskripsi ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildFeatureBadge(
                    context,
                    Icons.storage,
                    '${package.kuotaDisk} GB',
                  ),
                  const SizedBox(width: 8),
                  _buildFeatureBadge(
                    context,
                    Icons.language,
                    'Max ${package.maxDomain} Domain',
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: isDragging
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                  const Icon(Icons.drag_handle, color: Colors.grey),
                ],
              ),
      ),
    );
  }

  Widget _buildFeatureBadge(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[150],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
