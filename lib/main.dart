import 'package:flutter/material.dart';
import 'package:salary_app/screens/home_screen.dart';
import 'package:salary_app/services/settings_service.dart';
import 'package:salary_app/services/update_service.dart';
import 'package:salary_app/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      UpdateService.checkForUpdates(context, showNoUpdateMessage: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Georgina Stone Salary App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const HomeScreen(),
    );
  }
}
