import 'package:flutter/material.dart';

class SwipeRevealTile extends StatefulWidget {
  final String nama;
  final String email;
  final String status;
  final String packageName;
  final VoidCallback onEdit;
  final VoidCallback onSuspend;
  final VoidCallback? onDelete; // Added delete as an extra swipe action or fallback

  const SwipeRevealTile({
    Key? key,
    required this.nama,
    required this.email,
    required this.status,
    required this.packageName,
    required this.onEdit,
    required this.onSuspend,
    this.onDelete,
  }) : super(key: key);

  @override
  State<SwipeRevealTile> createState() => _SwipeRevealTileState();
}

class _SwipeRevealTileState extends State<SwipeRevealTile> {
  double _offset = 0;
  static const double _maxOffset = 240; // Increased to fit three buttons

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _offset = (_offset + d.delta.dx).clamp(-_maxOffset, 0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() {
      _offset = _offset < -(_maxOffset / 2) ? -_maxOffset : 0;
    });
  }

  void _reset() {
    setState(() {
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuspended = widget.status.toLowerCase() == 'suspended';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // Action Buttons in the background
              Positioned.fill(
                child: Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit Button
                      InkWell(
                        onTap: () {
                          _reset();
                          widget.onEdit();
                        },
                        child: Container(
                          width: 80,
                          color: Colors.blue.shade600,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 20),
                              SizedBox(height: 4),
                              Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      // Suspend / Activate Button
                      InkWell(
                        onTap: () {
                          _reset();
                          widget.onSuspend();
                        },
                        child: Container(
                          width: 80,
                          color: isSuspended ? Colors.green.shade600 : Colors.orange.shade700,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSuspended ? Icons.check_circle : Icons.block,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSuspended ? 'Aktifkan' : 'Suspend',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Delete Button
                      if (widget.onDelete != null)
                        InkWell(
                          onTap: () {
                            _reset();
                            widget.onDelete!();
                          },
                          child: Container(
                            width: 80,
                            color: Colors.red.shade600,
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete, color: Colors.white, size: 20),
                                const SizedBox(height: 4),
                                Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Main Tile Content that slides
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.translationValues(_offset, 0, 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(
                    color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isSuspended ? Colors.red.shade100 : Colors.teal.shade100,
                    child: Text(
                      widget.nama.isNotEmpty ? widget.nama[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: isSuspended ? Colors.red.shade800 : Colors.teal.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.nama,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSuspended ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.status.toUpperCase(),
                          style: TextStyle(
                            color: isSuspended ? Colors.red : Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.email,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.cloud_queue, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              widget.packageName,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
