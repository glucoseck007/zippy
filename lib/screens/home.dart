import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              final currentLocale = context.locale;
              final newLocale = currentLocale.languageCode == 'en'
                  ? const Locale('vi', 'VN')
                  : const Locale('en', 'US');
              context.setLocale(newLocale);
            },
          )
        ],
      ),
      body: Center(
        child: SwitchListTile(
          title: Text(tr('toggle')),
          value: isDark,
          onChanged: themeProvider.toggleTheme,
        ),
      ),
    );
  }
}
