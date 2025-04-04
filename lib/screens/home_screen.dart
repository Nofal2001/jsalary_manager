import 'dart:convert';
import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  final bool disableUpdateCheck; // ✅ Added this

  const HomeScreen({super.key, this.disableUpdateCheck = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Widget _currentView = const DashboardChart();

  @override
  void initState() {
    super.initState();
    if (!widget.disableUpdateCheck) {
      _checkForUpdatesSilently(); // ✅ Conditional update check
    }
  }

  void _setView(Widget view) {
    setState(() => _currentView = view);
  }

  Future<void> _checkForUpdatesSilently() async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      final response = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/Nofal2001/salary_app/main/version.json',
      ));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final latestVersion = json['version'].toString().trim();
        final url = json['downloadUrl'];

        if (latestVersion != currentVersion && context.mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("🆕 Update Available"),
              content: Text(
                  "A new version ($latestVersion) is available.\nWould you like to download it?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Later")),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Download")),
              ],
            ),
          );

          if (confirm == true && await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Failed to check for updates: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Row(
        children: [
          Container(
            width: 220,
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                SidebarButton(
                  icon: LucideIcons.userPlus,
                  label: 'Add Worker',
                  onPressed: () => _setView(const AddWorkerDialog(embed: true)),
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
                  icon: LucideIcons.history,
                  label: 'View History',
                  onPressed: () => _setView(const HistoryMainWindow()),
                ),
                const Spacer(),
                SidebarButton(
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  onPressed: () async {
                    final authorized = await AdminPinDialog.verifyPin(context);
                    if (authorized) {
                      _setView(const SettingsScreen());
                    } else {
                      AppTheme.showWarningSnackbar(context, "❌ Incorrect PIN");
                    }
                  },
                ),
                const SizedBox(height: 20),
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
    );
  }
}

class SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const SidebarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: SizedBox(
        width: 180,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }
}

class DashboardChart extends StatelessWidget {
  const DashboardChart({super.key});

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
            child: Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: const LineChartWidget(),
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
