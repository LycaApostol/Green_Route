import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacySettings extends StatefulWidget {
  const PrivacySettings({super.key});

  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  bool _shareLocation = true;
  bool _shareUsageData = false;
  bool _personalizedAds = false;
  bool _biometricAuth = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shareLocation = prefs.getBool('share_location') ?? true;
      _shareUsageData = prefs.getBool('share_usage_data') ?? false;
      _personalizedAds = prefs.getBool('personalized_ads') ?? false;
      _biometricAuth = prefs.getBool('biometric_auth') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('share_location', _shareLocation);
    await prefs.setBool('share_usage_data', _shareUsageData);
    await prefs.setBool('personalized_ads', _personalizedAds);
    await prefs.setBool('biometric_auth', _biometricAuth);
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _showMessage('No user signed in');
      return;
    }

    final TextEditingController emailController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A password reset link will be sent to your email.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailController.text.trim().isEmpty 
              ? user.email! 
              : emailController.text.trim(),
        );
        if (mounted) {
          _showMessage('Password reset email sent', isError: false);
        }
      } catch (e) {
        if (mounted) {
          _showMessage('Error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Simulate cache clearing
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _showMessage('Cache cleared successfully', isError: false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.delete();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
          }
        }
      } catch (e) {
        if (mounted) {
          _showMessage('Error deleting account. You may need to re-authenticate.');
        }
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy & Security')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18.0),
          children: [
            const Text(
              'Privacy & Security',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your privacy and security settings',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Section
            _buildSection(
              title: 'Privacy',
              children: [
                _buildSwitchTile(
                  icon: Icons.location_on,
                  title: 'Share Location',
                  subtitle: 'Allow app to access your location',
                  value: _shareLocation,
                  onChanged: (value) {
                    setState(() => _shareLocation = value);
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.analytics_outlined,
                  title: 'Share Usage Data',
                  subtitle: 'Help improve the app',
                  value: _shareUsageData,
                  onChanged: (value) {
                    setState(() => _shareUsageData = value);
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.ad_units,
                  title: 'Personalized Ads',
                  subtitle: 'Show ads based on your interests',
                  value: _personalizedAds,
                  onChanged: (value) {
                    setState(() => _personalizedAds = value);
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Security Section
            _buildSection(
              title: 'Security',
              children: [
                _buildSwitchTile(
                  icon: Icons.fingerprint,
                  title: 'Biometric Authentication',
                  subtitle: 'Use fingerprint or face ID',
                  value: _biometricAuth,
                  onChanged: (value) {
                    setState(() => _biometricAuth = value);
                    _saveSettings();
                    _showMessage(
                      'Biometric authentication ${value ? "enabled" : "disabled"}',
                      isError: false,
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.lock_reset,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  trailing: Icons.chevron_right,
                  onTap: _changePassword,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSection(
              title: 'Data Management',
              children: [
                _buildActionTile(
                  icon: Icons.file_download,
                  title: 'Download My Data',
                  subtitle: 'Get a copy of your data',
                  trailing: Icons.chevron_right,
                  onTap: () {
                    _showMessage('Feature coming soon', isError: false);
                  },
                ),
                _buildActionTile(
                  icon: Icons.cleaning_services,
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  trailing: Icons.chevron_right,
                  onTap: _clearCache,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Legal Section
            _buildSection(
              title: 'Legal',
              children: [
                _buildActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  trailing: Icons.open_in_new,
                  onTap: () {
                    _showMessage('Opening privacy policy...', isError: false);
                  },
                ),
                _buildActionTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Read our terms of service',
                  trailing: Icons.open_in_new,
                  onTap: () {
                    _showMessage('Opening terms of service...', isError: false);
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Danger Zone
            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeThumbColor: Colors.green,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required IconData trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(trailing, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}