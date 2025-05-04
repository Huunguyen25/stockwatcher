import 'package:flutter/material.dart';
import 'package:stockwatcher/services/firebase_service.dart';

class ProfileScreen extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  ProfileScreen({super.key});

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    String username = parts[0];
    String domain = parts[1];

    // If username is too short, just mask the middle
    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }

    // Otherwise, show first and last character of username
    return '${username[0]}${('*' * (username.length - 2))}${username[username.length - 1]}@$domain';
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firebaseService.deleteAccount();
      if (context.mounted) {
        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await _firebaseService.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _firebaseService.currentUser?.email ?? '';
    final maskedEmail = _maskEmail(userEmail);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    maskedEmail,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.blue),
              title: const Text('Sign Out'),
              onTap: () => _handleSignOut(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _handleDeleteAccount(context),
            ),
          ],
        ),
      ),
    );
  }
}
