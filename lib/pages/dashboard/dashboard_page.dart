import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/preferences/app_preferences.dart';
import '../../widgets/stat_card_painter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _adminUsername = '';
  String _lastLogin = '';
  int _cardCount = 4;

  int _totalDomains = 0;
  int _totalUsers = 0;
  int _totalPackages = 0;
  int _openTickets = 0;

  String _domainBreakdown = '';
  String _userBreakdown = '';
  String _packageBreakdown = '';
  String _ticketBreakdown = '';

  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _refreshData();
  }

  void _loadPreferences() {
    setState(() {
      _adminUsername = AppPreferences.getAdminUsername();
      _cardCount = AppPreferences.getDashboardCardCount();

      final rawLogin = AppPreferences.getLastLoginTs();
      if (rawLogin.isNotEmpty) {
        final parsedDate = DateTime.parse(rawLogin);
        _lastLogin = DateFormat('dd MMM yyyy, HH:mm').format(parsedDate);
      } else {
        _lastLogin = '-';
      }
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);

    try {
      final totalDomains = await _dbHelper.getCount('domains');
      final totalUsers = await _dbHelper.getCount('users');
      final totalPackages = await _dbHelper.getCount('packages');
      final openTickets = await _dbHelper.getOpenTicketsCount();

      // Breakdowns for the back of cards
      final listDomains = await _dbHelper.getDomains();
      final dAktif = listDomains
          .where((d) => d.status.toLowerCase() == 'aktif')
          .length;
      final dExpired = listDomains
          .where((d) => d.status.toLowerCase() == 'expired')
          .length;
      final dSuspended = listDomains
          .where((d) => d.status.toLowerCase() == 'suspended')
          .length;
      final domainBreakdown =
          "$dAktif Aktif, $dExpired Expired, $dSuspended Suspended";

      final listUsers = await _dbHelper.getUsers();
      final uAktif = listUsers
          .where((u) => u.status.toLowerCase() == 'aktif')
          .length;
      final uSuspended = listUsers
          .where((u) => u.status.toLowerCase() == 'suspended')
          .length;
      final userBreakdown = "$uAktif Aktif, $uSuspended Suspended";

      final listPackages = await _dbHelper.getPackages();
      final packageBreakdown = listPackages.map((p) => p.namaPaket).join(', ');

      final tOpen = await _dbHelper.getOpenTicketsCount();
      final tProgress = (await _dbHelper.getTickets('in_progress')).length;
      final tClosed = (await _dbHelper.getTickets('closed')).length;
      final ticketBreakdown =
          "$tOpen Open, $tProgress In Progress, $tClosed Closed";

      // Load Chart Data
      final monthlyData = await _dbHelper.getDomainsRegisteredPerMonth();
      final List<Map<String, dynamic>> chartList = [];
      final now = DateTime.now();

      // Calculate last 6 months
      for (int i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthStr = DateFormat('yyyy-MM').format(date);
        double count = 0;

        for (var row in monthlyData) {
          if (row['month'] == monthStr) {
            count = (row['count'] as num).toDouble();
            break;
          }
        }

        chartList.add({
          'month': DateFormat('MMM').format(date),
          'count': count,
        });
      }

      setState(() {
        _totalDomains = totalDomains;
        _totalUsers = totalUsers;
        _totalPackages = totalPackages;
        _openTickets = openTickets;

        _domainBreakdown = domainBreakdown;
        _userBreakdown = userBreakdown;
        _packageBreakdown = packageBreakdown;
        _ticketBreakdown = ticketBreakdown;

        _chartData = chartList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard data: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'KolabPanel Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPreferences();
              _refreshData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _loadPreferences();
              _refreshData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.teal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header Card
                    _buildWelcomeCard(isDark),
                    const SizedBox(height: 24),

                    // Stats Grid
                    Text(
                      'Statistik Ringkas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Klik/Tahan kartu untuk melihat detail breakdown',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatsGrid(),
                    const SizedBox(height: 28),

                    // Chart Section
                    Text(
                      'Domain Terdaftar (6 Bulan Terakhir)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChartCard(isDark),
                    const SizedBox(height: 28),

                    // Shortcuts Section
                    Text(
                      'Menu Pintasan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildShortcutsGrid(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.teal.shade900.withOpacity(0.8),
                  Colors.blueGrey.shade900.withOpacity(0.8),
                ]
              : [Colors.teal.shade500, Colors.teal.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                'Halo, $_adminUsername',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Login terakhir: $_lastLogin',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kelola domain, user, paket hosting, dan tiket support klien dengan mudah dalam satu dashboard.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final allCards = [
      StatCardWidget(
        title: 'Total Domain',
        value: _totalDomains,
        color: Colors.teal,
        icon: Icons.language,
        breakdown: _domainBreakdown,
      ),
      StatCardWidget(
        title: 'Total User',
        value: _totalUsers,
        color: Colors.blue.shade600,
        icon: Icons.people,
        breakdown: _userBreakdown,
      ),
      StatCardWidget(
        title: 'Paket Hosting',
        value: _totalPackages,
        color: Colors.orange.shade700,
        icon: Icons.layers,
        breakdown: _packageBreakdown,
      ),
      StatCardWidget(
        title: 'Tiket Open',
        value: _openTickets,
        color: Colors.red.shade600,
        icon: Icons.confirmation_number,
        breakdown: _ticketBreakdown,
      ),
    ];

    // Filter by package preferences card count
    final displayedCards = allCards.take(_cardCount).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.8,
      ),
      itemCount: displayedCards.length,
      itemBuilder: (context, index) => displayedCards[index],
    );
  }

  Widget _buildChartCard(bool isDark) {
    if (_chartData.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Tidak ada data chart')),
      );
    }

    double maxVal = 5;
    for (var d in _chartData) {
      if (d['count'] > maxVal) {
        maxVal = (d['count'] as double) + 2;
      }
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.teal.shade700,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${_chartData[group.x.toInt()]['month']}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: '${rod.toY.toInt()} Domain',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < _chartData.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        _chartData[index]['month'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == value.toInt()) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(_chartData.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: _chartData[index]['count'],
                  color: Colors.teal,
                  width: 18,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildShortcutsGrid() {
    final shortcuts = [
      _ShortcutItem(
        title: 'Domains',
        icon: Icons.language,
        color: Colors.teal,
        route: '/domains',
      ),
      _ShortcutItem(
        title: 'Users',
        icon: Icons.people,
        color: Colors.blue.shade600,
        route: '/users',
      ),
      _ShortcutItem(
        title: 'Packages',
        icon: Icons.layers,
        color: Colors.orange.shade700,
        route: '/packages',
      ),
      _ShortcutItem(
        title: 'Tickets',
        icon: Icons.confirmation_number,
        color: Colors.red.shade600,
        route: '/tickets',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemCount: shortcuts.length,
      itemBuilder: (context, index) {
        final item = shortcuts[index];
        return InkWell(
          onTap: () async {
            await Navigator.pushNamed(context, item.route);
            _loadPreferences();
            _refreshData();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]!
                    : Colors.grey[200]!,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: item.color, size: 36),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShortcutItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _ShortcutItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });
}
