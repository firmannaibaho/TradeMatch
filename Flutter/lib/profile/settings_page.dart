import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trade_match/auth/welcome_page.dart';
import 'package:trade_match/profile/edit_profile_page.dart';
import 'package:trade_match/screens/notifications_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Sign out from Supabase
        await Supabase.instance.client.auth.signOut();

        if (context.mounted) {
          // Navigate to welcome page and clear navigation stack
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to logout: $e')));
        }
      }
    }
  }

  void _handleChangePassword(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found for password reset')),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset email: $e')),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'TradeMatch',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.swap_horiz,
        size: 48,
        color: Colors.orange,
      ),
      applicationLegalese: '© 2024 TradeMatch Team\nAll rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'TradeMatch is a bartering platform that connects people who want to trade items without using money.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Pengaturan',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Ubah Foto / Bio'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Ganti Password'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _handleChangePassword(context),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_outlined),
            title: const Text('Notifikasi'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Aplikasi'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => _handleLogout(context),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
