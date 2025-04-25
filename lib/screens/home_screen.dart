import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jsalary_manager/services/local_db_service.dart';
import 'package:jsalary_manager/widgets/employee_history_dialog.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jsalary_manager/widgets/admin_pin_dialog.dart';
import '../widgets/add_worker_dialog.dart';
import '../widgets/calculate_salary_dialog.dart';
import '../widgets/advance_payment_dialog.dart';
import '../screens/history_main_window.dart';
import '../theme/theme.dart';
import 'settings_screen.dart';
import '../widgets/add_client_dialog.dart';
import '../widgets/add_income_dialog.dart';
import '../widgets/add_expense_dialog.dart';
import '../screens/vault_main_window.dart';

class HomeScreen extends StatefulWidget {
  final bool disableUpdateCheck;
  const HomeScreen({super.key, this.disableUpdateCheck = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Widget _currentView = const DashboardOverview();
  bool _checkingUpdate = false;
  late AnimationController _fadeController;
  bool _hoveringLogo = false;
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.disableUpdateCheck) _checkForUpdatesSilently();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _setView(Widget newView) {
    setState(() {
      _currentView = AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: newView,
      );
    });
  }

  Future<void> _checkForUpdatesSilently() async {
    setState(() => _checkingUpdate = true);
    _fadeController.forward();

    try {
      final response = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/Nofal2001/salary_app/main/version.json',
      ));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestVersion = json['version'].toString().trim();
        final downloadUrl = json['downloadUrl'];
        final currentVersion = (await PackageInfo.fromPlatform()).version;

        if (latestVersion != currentVersion && context.mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("🆕 Update Available"),
              content: Text("A new version ($latestVersion) is available."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Later"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse(downloadUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  child: const Text("Download"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Update check failed: $e")),
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _fadeController.reverse().whenComplete(() {
      setState(() => _checkingUpdate = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.bgColor,
          body: Row(
            children: [
              Container(
                width: 220,
                color: const Color(0xFF1A1A1A),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () => _setView(const DashboardOverview()),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoveringLogo = true),
                          onExit: (_) => setState(() => _hoveringLogo = false),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 1.0, end: _hoveringLogo ? 1.08 : 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/logo.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SidebarButton(
                      icon: LucideIcons.userPlus,
                      label: 'Add Worker',
                      onPressed: () =>
                          _setView(const AddWorkerDialog(embed: true)),
                    ),
                    SidebarButton(
                      icon: LucideIcons.users,
                      label: 'Add Client',
                      onPressed: () =>
                          _setView(const AddClientDialog(embed: true)),
                    ),
                    SidebarButton(
                      icon: LucideIcons.calculator,
                      label: 'Calculate Salary',
                      onPressed: () =>
                          _setView(const CalculateSalaryDialog(embed: true)),
                    ),
                    SidebarButton(
                      icon: LucideIcons.wallet,
                      label: 'Advance Payment',
                      onPressed: () =>
                          _setView(const AdvancePaymentDialog(embed: true)),
                    ),
                    SidebarButton(
                      icon: LucideIcons.arrowDownCircle,
                      label: 'Add Income',
                      onPressed: () =>
                          _setView(const AddIncomeDialog(embed: true)),
                    ),
                    SidebarButton(
                      icon: LucideIcons.arrowUpCircle,
                      label: 'Add Expense',
                      onPressed: () =>
                          _setView(const AddExpenseDialog(embed: true)),
                    ),
                    SidebarButton(
                      icon: LucideIcons.fileBarChart2,
                      label: 'View Vault',
                      onPressed: () => _setView(const VaultMainWindow()),
                    ),
                    SidebarButton(
                      icon: LucideIcons.history,
                      label: 'View History',
                      onPressed: () => _setView(const HistoryMainWindow()),
                    ),
                    const Spacer(),
                    SidebarButton(
                      icon: LucideIcons.settings,
                      label: 'Settings',
                      onPressed: () async {
                        final authorized =
                            await AdminPinDialog.verifyPin(context);
                        if (authorized) {
                          _setView(const SettingsScreen());
                        } else {
                          AppTheme.showWarningSnackbar(
                              context, "❌ Incorrect PIN");
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentView,
                ),
              ),
            ],
          ),
        ),

        // Update Spinner
        if (_checkingUpdate)
          FadeTransition(
            opacity: _fadeController,
            child: Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text("Checking for updates...",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────
// 💡 Stylish SidebarButton
class SidebarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? iconColor;

  const SidebarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
  });

  @override
  State<SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<SidebarButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _controller;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bounce = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    setState(() => _hovered = hovering);
    if (hovering) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_bounce.value * 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(vertical: 4),
              height: 42,
              width: 160,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.primaryColor.withOpacity(0.95)
                    : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 18,
                        color: widget.iconColor ?? Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────────────────────────────────
// Dashboard
class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key});

  Future<List<Map<String, dynamic>>> _getUpcomingPayments() async {
    final workers = await LocalDBService.getAllWorkers();
    final now = DateTime.now();

    return workers.where((worker) {
      final joinDate = DateTime.tryParse(worker['joinDate'] ?? '');
      if (joinDate == null) return false;
      final due = DateTime(now.year, now.month, joinDate.day);
      return due.month == now.month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📈 Dashboard Overview',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: AppTheme.cardDecoration,
                    padding: const EdgeInsets.all(16),
                    child: const LineChartWidget(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getUpcomingPayments(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final data = snapshot.data!;
                        if (data.isEmpty) {
                          return const Center(
                              child: Text("No upcoming salaries this month."));
                        }
                        final now = DateTime.now();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "📅 Next Salary Payments",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: data.length,
                                itemBuilder: (context, index) {
                                  // Sort: Missed payments first, then upcoming
                                  data.sort((a, b) {
                                    final now = DateTime.now();
                                    final dueA = DateTime(now.year, now.month,
                                        DateTime.parse(a['joinDate']).day);
                                    final dueB = DateTime(now.year, now.month,
                                        DateTime.parse(b['joinDate']).day);

                                    final isMissedA = dueA.isBefore(now);
                                    final isMissedB = dueB.isBefore(now);

                                    if (isMissedA && !isMissedB) return -1;
                                    if (!isMissedA && isMissedB) return 1;

                                    return dueA.compareTo(dueB);
                                  });

                                  final worker = data[index];
                                  final join =
                                      DateTime.parse(worker['joinDate']);
                                  final now = DateTime.now();
                                  final due =
                                      DateTime(now.year, now.month, join.day);
                                  final isMissed = due.isBefore(now);
                                  final formattedDate =
                                      DateFormat('d MMM').format(due);

                                  return StatefulBuilder(
                                    builder: (context, setHover) {
                                      bool _isHovered = false;

                                      return MouseRegion(
                                        onEnter: (_) =>
                                            setHover(() => _isHovered = true),
                                        onExit: (_) =>
                                            setHover(() => _isHovered = false),
                                        child: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  EmployeeHistoryDialog(
                                                      worker: worker),
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 12),
                                            margin: const EdgeInsets.only(
                                                bottom: 10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: isMissed
                                                  ? Colors.red.withOpacity(0.08)
                                                  : _isHovered
                                                      ? Colors.grey.shade100
                                                          .withOpacity(0.5)
                                                      : Colors.grey.shade100,
                                              boxShadow: _isHovered
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.05),
                                                        blurRadius: 6,
                                                        offset:
                                                            const Offset(0, 3),
                                                      )
                                                    ]
                                                  : [],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(worker['name'],
                                                        style: const TextStyle(
                                                            fontSize: 15)),
                                                    if (isMissed) ...[
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                          Icons
                                                              .notification_important,
                                                          color: Colors.red,
                                                          size: 18),
                                                    ],
                                                  ],
                                                ),
                                                Text(formattedDate,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LineChartWidget extends StatelessWidget {
  const LineChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 1375.02),
              FlSpot(1, 1760.32),
              FlSpot(2, 1662.47),
              FlSpot(3, 1572.74),
              FlSpot(4, 2012.04),
              FlSpot(5, 1939.21),
            ],
            isCurved: true,
            color: Colors.amber.shade800,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.amber.shade100.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
