import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_default_location.dart';
import 'settings_notifications.dart';
import 'settings_privacy.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    // Confirm logout with user
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out')),
        ],
      ),
    );

    if (confirm != true) return;

    // Perform Firebase logout
    await FirebaseAuth.instance.signOut();

    // Navigate back to the Welcome or Login screen
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundImage: AssetImage('assets/avatar_placeholder.png'), // replace if needed
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Kinemberlo', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('View/edit profile'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                title: const Text('Default Location'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DefaultLocationSettings()),
                ),
              ),
              ListTile(
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsSettings()),
                ),
              ),
              ListTile(
                title: const Text('Privacy & Security'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacySettings()),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _logout(context),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
