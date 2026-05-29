import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../models/ticket_model.dart';

class TicketListPage extends StatefulWidget {
  const TicketListPage({Key? key}) : super(key: key);

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;

  List<TicketModel> _openTickets = [];
  List<TicketModel> _inProgressTickets = [];
  List<TicketModel> _closedTickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchTickets();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _fetchTickets();
    }
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final openList = await _dbHelper.getTickets('open');
      final progressList = await _dbHelper.getTickets('in_progress');
      final closedList = await _dbHelper.getTickets('closed');

      setState(() {
        _openTickets = openList;
        _inProgressTickets = progressList;
        _closedTickets = closedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tickets: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _updateTicketStatus(TicketModel ticket, String newStatus) async {
    final updated = ticket.copyWith(
      status: newStatus,
      tanggalUpdate: DateTime.now().toString(),
    );

    try {
      await _dbHelper.updateTicket(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status tiket berhasil diperbarui menjadi "$newStatus"',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _fetchTickets();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status tiket: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteTicket(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tiket'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus tiket yang sudah ditutup ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteTicket(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiket berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchTickets();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tiket: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Support Tickets',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.teal,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Open', icon: Icon(Icons.mail_outline)),
            Tab(text: 'In Progress', icon: Icon(Icons.sync)),
            Tab(text: 'Closed', icon: Icon(Icons.check_circle_outline)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/tickets/add');
          if (result == true) _fetchTickets();
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTicketList(_openTickets, 'open'),
                _buildTicketList(_inProgressTickets, 'in_progress'),
                _buildTicketList(_closedTickets, 'closed'),
              ],
            ),
    );
  }

  Widget _buildTicketList(List<TicketModel> tickets, String tabStatus) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada tiket di tab ini',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTickets,
      color: Colors.teal,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          final priorityColor = _getPriorityColor(ticket.prioritas);

          DateTime? createdDate;
          String formattedDate = ticket.tanggalBuat;
          try {
            createdDate = DateTime.parse(ticket.tanggalBuat);
            formattedDate = DateFormat(
              'dd MMM yyyy, HH:mm',
            ).format(createdDate);
          } catch (_) {}

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Slidable(
                key: ValueKey(ticket.id),
                // Swipe right (startActionPane) to mark as In Progress (for open tickets)
                startActionPane: tabStatus == 'open'
                    ? ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) =>
                                _updateTicketStatus(ticket, 'in_progress'),
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            icon: Icons.sync,
                            label: 'Proses',
                          ),
                        ],
                      )
                    : null,
                // Swipe left (endActionPane)
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    // For Open / In Progress, allow closing the ticket
                    if (tabStatus == 'open' || tabStatus == 'in_progress')
                      SlidableAction(
                        onPressed: (context) =>
                            _updateTicketStatus(ticket, 'closed'),
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        icon: Icons.check_circle_outline,
                        label: 'Tutup',
                      ),
                    // For closed tickets, allow deletion
                    if (tabStatus == 'closed')
                      SlidableAction(
                        onPressed: (context) {
                          if (ticket.id != null) {
                            _deleteTicket(ticket.id!);
                          }
                        },
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Hapus',
                      ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subjek,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Priority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: priorityColor.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          ticket.prioritas.toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
                          'Client: ${ticket.namaUser ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/tickets/detail',
                      arguments: ticket,
                    );
                    if (result == true) _fetchTickets();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
