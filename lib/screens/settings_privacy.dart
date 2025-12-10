import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:otp/otp.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

class PrivacySettings extends StatefulWidget {
  const PrivacySettings({super.key});

  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  bool _isLoading = true;
  bool _twoFactorEnabled = false;
  DateTime? _lastPasswordChange;
  String? _totpSecret;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _twoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
      _totpSecret = prefs.getString('totp_secret');
      final timestamp = prefs.getInt('last_password_change');
      if (timestamp != null) {
        _lastPasswordChange = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('two_factor_enabled', _twoFactorEnabled);
    if (_totpSecret != null) {
      await prefs.setString('totp_secret', _totpSecret!);
    } else {
      await prefs.remove('totp_secret');
    }
    if (_lastPasswordChange != null) {
      await prefs.setInt('last_password_change', _lastPasswordChange!.millisecondsSinceEpoch);
    }
  }

  String _getPasswordChangeText() {
    if (_lastPasswordChange == null) {
      return 'Never changed';
    }
    
    final now = DateTime.now();
    final difference = now.difference(_lastPasswordChange!);
    
    if (difference.inDays < 30) {
      return 'Last changed ${difference.inDays} days ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'Last changed $months ${months == 1 ? "month" : "months"} ago';
    }
  }

  // Generate a random secret for TOTP
  String _generateSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Generate TOTP URI for QR code
  String _generateTotpUri(String secret, String email) {
    return 'otpauth://totp/GreenRoute:$email?secret=$secret&issuer=GreenRoute';
  }

  // Verify TOTP code
  bool _verifyTotpCode(String code, String secret) {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentCode = OTP.generateTOTPCodeString(
        secret,
        now,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      
      // Also check previous and next time window for clock skew
      final prevCode = OTP.generateTOTPCodeString(
        secret,
        now - 30000,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      
      final nextCode = OTP.generateTOTPCodeString(
        secret,
        now + 30000,
        length: 6,
        interval: 30,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      
      return code == currentCode || code == prevCode || code == nextCode;
    } catch (e) {
      return false;
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _showMessage('No user signed in');
      return;
    }

    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (newPasswordController.text != confirmPasswordController.text) {
        _showMessage('Passwords do not match');
        return;
      }

      if (newPasswordController.text.length < 6) {
        _showMessage('Password must be at least 6 characters');
        return;
      }

      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPasswordController.text);
        
        setState(() {
          _lastPasswordChange = DateTime.now();
        });
        await _saveSettings();
        
        if (mounted) {
          _showMessage('Password changed successfully', isError: false);
        }
      } catch (e) {
        if (mounted) {
          _showMessage('Error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _toggleTwoFactor() async {
    if (_twoFactorEnabled) {
      await _disableTwoFactor();
    } else {
      await _enableTwoFactor();
    }
  }

  Future<void> _enableTwoFactor() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _showMessage('No user signed in');
      return;
    }

    // Generate secret
    final secret = _generateSecret();
    final email = user.email ?? 'user@greenroute.com';
    final totpUri = _generateTotpUri(secret, email);

    // Show QR code setup dialog
    final TextEditingController codeController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setup Authenticator'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan this QR code with your authenticator app:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Google Authenticator\n• Microsoft Authenticator\n• Authy\n• Any TOTP app',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: totpUri,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Or enter this key manually:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        secret,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: secret));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Secret copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter the 6-digit code from your app:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify & Enable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final enteredCode = codeController.text.trim();

      if (enteredCode.length != 6) {
        _showMessage('Please enter a valid 6-digit code');
        return;
      }

      // Verify the code
      if (_verifyTotpCode(enteredCode, secret)) {
        setState(() {
          _twoFactorEnabled = true;
          _totpSecret = secret;
        });
        await _saveSettings();
        
        _showMessage('Two-factor authentication enabled successfully! ✓', isError: false);
      } else {
        _showMessage('Invalid verification code. Please try again.');
      }
    }
  }

  Future<void> _disableTwoFactor() async {
    if (_totpSecret == null) {
      setState(() {
        _twoFactorEnabled = false;
      });
      await _saveSettings();
      return;
    }

    // Verify with TOTP code before disabling
    final TextEditingController codeController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable Two-Factor Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your authenticator code to confirm:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will make your account less secure.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (result == true) {
      final enteredCode = codeController.text.trim();

      if (enteredCode.length != 6) {
        _showMessage('Please enter a valid 6-digit code');
        return;
      }

      // Verify the code
      if (_verifyTotpCode(enteredCode, _totpSecret!)) {
        setState(() {
          _twoFactorEnabled = false;
          _totpSecret = null;
        });
        await _saveSettings();
        
        _showMessage('Two-factor authentication disabled', isError: false);
      } else {
        _showMessage('Invalid verification code');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _showMessage('No user signed in');
      return;
    }

    final TextEditingController passwordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please enter your password to confirm:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (passwordController.text.isEmpty) {
        _showMessage('Please enter your password');
        return;
      }

      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.delete();
        
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          _showMessage('Error: ${e.toString()}');
        }
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Privacy & Security'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            const SizedBox(height: 8),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'ACCOUNT SECURITY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            _buildSettingTile(
              title: 'Change Password',
              subtitle: _getPasswordChangeText(),
              onTap: _changePassword,
            ),
            
            const Divider(height: 1, indent: 16),

            _buildSettingTile(
              title: 'Two-Factor Authentication',
              subtitle: _twoFactorEnabled 
                  ? 'Authenticator app protection enabled' 
                  : 'Extra security for your account',
              onTap: _toggleTwoFactor,
              trailing: _twoFactorEnabled 
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                  : null,
            ),
            
            const Divider(height: 1, indent: 16),

            _buildSettingTile(
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              onTap: _deleteAccount,
              titleColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: titleColor ?? Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}