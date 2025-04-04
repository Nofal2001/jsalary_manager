import 'package:flutter/material.dart';

Map<String, MaterialColor> accentColors = {
  'green': Colors.green,
  'blue': Colors.blue,
  'stone': Colors.brown,
  'purple': Colors.deepPurple,
  'orange': Colors.orange,
};

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFFD4A017);
  static const Color bgColor = Color(0xFFFAF9F6);
  static const Color cardBgColor = Colors.white;
  static const Color successColor = Color(0xFF28A745);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFDC3545);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF555555);

  // Text styles
  static const TextStyle headline1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static InputDecoration inputDecoration(String label) {
    return InputDecoration(
      label: Text(label),
      filled: true,
      fillColor: bgColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    color: textPrimary,
  );
  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    color: textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );

  // Main theme
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: false,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: cardBgColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        color: primaryColor,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      textTheme: const TextTheme(
        displayLarge: headline1,
        displayMedium: headline2,
        bodyLarge: bodyText1,
        bodyMedium: bodyText2,
        bodySmall: caption,
      ),
      cardTheme: CardTheme(
        color: cardBgColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Card decoration
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: cardBgColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Dialog
  static Future<T?> showAppDialog<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: headline2),
              const SizedBox(height: 16),
              content,
              if (actions != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Snackbar helpers
  static void showSuccessSnackbar(BuildContext context, String msg) {
    _showStyledSnackbar(context, msg, successColor);
  }

  static void showErrorSnackbar(BuildContext context, String msg) {
    _showStyledSnackbar(context, msg, errorColor);
  }

  static void showWarningSnackbar(BuildContext context, String msg) {
    _showStyledSnackbar(context, msg, warningColor);
  }

  static void _showStyledSnackbar(BuildContext context, String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_getSnackbarIcon(bg), color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }

  static IconData _getSnackbarIcon(Color color) {
    if (color == successColor) return Icons.check_circle_outline;
    if (color == errorColor) return Icons.error_outline;
    return Icons.warning_amber;
  }
}
