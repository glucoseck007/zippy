import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth/authorization_service.dart';
import '../services/api_client.dart';
import '../widgets/permission_widgets.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  void _checkAccess() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = AuthorizationService.authorize(
      user: authProvider.currentUser,
      featureName: 'admin_panel',
    );

    if (result.isDenied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.reason ?? 'Access denied'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } else {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.get('/admin/users');

      if (ApiClient.isSuccessResponse(response)) {
        final data = ApiClient.handleResponse(response);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['users'] ?? []);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        // Mock data for demonstration since API might not exist
        _users = [
          {
            'id': '1',
            'username': 'john_doe',
            'email': 'john@example.com',
            'role': 'customer',
            'isVerified': true,
            'createdAt': '2024-01-01T00:00:00Z',
          },
          {
            'id': '2',
            'username': 'admin_user',
            'email': 'admin@example.com',
            'role': 'admin',
            'isVerified': true,
            'createdAt': '2024-01-01T00:00:00Z',
          },
          {
            'id': '3',
            'username': 'driver_mike',
            'email': 'driver@example.com',
            'role': 'driver',
            'isVerified': true,
            'createdAt': '2024-01-01T00:00:00Z',
          },
        ];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserStatus(String userId, bool isVerified) async {
    try {
      await ApiClient.patch(
        '/admin/users/$userId',
        body: {'isVerified': isVerified},
      );

      await _loadUsers(); // Reload users

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update user: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: const [UserRoleInfo(), SizedBox(width: 16)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Features Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Only show for admin users
                    PermissionGuard(
                      requiredRole: Role.admin,
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'System settings would open here',
                                  ),
                                ),
                              );
                            },
                            child: const Text('System Settings'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reports would be generated here',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Generate Reports'),
                          ),
                        ],
                      ),
                      fallback: const Text(
                        'Admin-only features are hidden',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Role-based content
            RoleBasedWidget(
              adminWidget: const Card(
                color: Colors.red,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Admin Dashboard: Full access to all features',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              userWidget: const Card(
                color: Colors.blue,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'User Dashboard: Limited access',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              defaultWidget: const Card(
                color: Colors.grey,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Limited access: Contact administrator for more permissions',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Users List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Users Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_errorMessage != null)
                        Column(
                          children: [
                            Text(
                              'Mock data shown (API error: $_errorMessage)',
                              style: const TextStyle(color: Colors.orange),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),

                      if (_users.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(user['username'] ?? 'Unknown'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(user['email'] ?? 'No email'),
                                      Text(
                                        'Role: ${user['role'] ?? 'customer'}',
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Chip(
                                        label: Text(
                                          user['isVerified'] == true
                                              ? 'Verified'
                                              : 'Unverified',
                                        ),
                                        backgroundColor:
                                            user['isVerified'] == true
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 8),

                                      // Permission-based button
                                      PermissionButton(
                                        requiredRole: Role.admin,
                                        onPressed: () {
                                          _updateUserStatus(
                                            user['id'],
                                            !(user['isVerified'] == true),
                                          );
                                        },
                                        child: Text(
                                          user['isVerified'] == true
                                              ? 'Suspend'
                                              : 'Verify',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
