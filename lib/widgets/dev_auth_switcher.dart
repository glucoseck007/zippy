import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zippy/design/app_colors.dart';
import '../providers/auth_provider.dart';

/// A widget that provides debug controls for switching between authentication states
/// This widget will only be visible in debug mode
class DevAuthSwitcher extends StatelessWidget {
  const DevAuthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      bottom: 80,
      right: 16,
      child: FloatingActionButton.small(
        backgroundColor: AppColors.buttonColor,
        onPressed: () => _showAuthOptions(context),
        tooltip: 'Developer Auth Options',
        child: const Icon(Icons.admin_panel_settings),
      ),
    );
  }

  void _showAuthOptions(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚠️ DEVELOPMENT AUTH SWITCHER',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(),
              const Text(
                'This panel is only visible during development. '
                'Use it to switch between authentication states without logging in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Mock User Auth'),
                subtitle: const Text('Simulate standard user login'),
                leading: const Icon(Icons.person),
                onTap: () {
                  authProvider.setMockAuthentication(role: 'USER');
                  Navigator.pop(context);
                  _showSuccessMessage(context, 'Authenticated as User');
                },
              ),
              ListTile(
                title: const Text('Mock Admin Auth'),
                subtitle: const Text('Simulate admin user login'),
                leading: const Icon(Icons.admin_panel_settings),
                onTap: () {
                  authProvider.setMockAuthentication(role: 'ADMIN');
                  Navigator.pop(context);
                  _showSuccessMessage(context, 'Authenticated as Admin');
                },
              ),
              ListTile(
                title: const Text('Log Out'),
                subtitle: const Text('Clear authentication'),
                leading: const Icon(Icons.logout),
                onTap: () {
                  authProvider.logout();
                  Navigator.pop(context);
                  _showSuccessMessage(context, 'Logged out');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ DEVELOPMENT MODE: $message'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
