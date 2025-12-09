import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettings extends StatefulWidget {
  const NotificationsSettings({super.key});

  @override
  State<NotificationsSettings> createState() => _NotificationsSettingsState();
}

class _NotificationsSettingsState extends State<NotificationsSettings> {
  bool _allowNotifications = true;
  bool _arrivalNotifications = true;
  String _soundVibration = 'Default';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowNotifications = prefs.getBool('allow_notifications') ?? true;
      _arrivalNotifications = prefs.getBool('arrival_notifications') ?? true;
      _soundVibration = prefs.getString('sound_vibration') ?? 'Default';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_notifications', _allowNotifications);
    await prefs.setBool('arrival_notifications', _arrivalNotifications);
    await prefs.setString('sound_vibration', _soundVibration);
  }

  Future<void> _showSoundVibrationPicker() async {
    final options = ['Default', 'Vibrate Only', 'Silent', 'Custom'];
    
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sound & Vibration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ...options.map((option) => ListTile(
              title: Text(option),
              trailing: _soundVibration == option
                  ? Icon(Icons.check, color: Colors.green[700])
                  : null,
              onTap: () {
                setState(() => _soundVibration = option);
                _saveSettings();
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Notifications'),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'NOTIFICATION SETTINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _buildNotificationTile(
              title: 'Allow Notifications',
              subtitle: 'Allow app to detect your location automatically',
              value: _allowNotifications,
              onChanged: (value) {
                setState(() {
                  _allowNotifications = value;
                  if (!value) {
                    _arrivalNotifications = false;
                  }
                });
                _saveSettings();
              },
            ),
            const Divider(height: 1, indent: 16),
            _buildNotificationTile(
              title: 'Arrival Notifications',
              subtitle: 'When you reach your destination',
              value: _arrivalNotifications,
              enabled: _allowNotifications,
              onChanged: (value) {
                setState(() => _arrivalNotifications = value);
                _saveSettings();
              },
            ),
            const Divider(height: 1, indent: 16),
            _buildSettingTile(
              title: 'Sound & Vibration',
              subtitle: 'Customize notification sounds',
              trailing: _soundVibration,
              enabled: _allowNotifications,
              onTap: _allowNotifications ? _showSoundVibrationPicker : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: enabled ? Colors.black87 : Colors.grey[400],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ),
        value: value,
        activeColor: Colors.green[600],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: Colors.white,
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
                      fontWeight: FontWeight.w500,
                      color: enabled ? Colors.black87 : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? Colors.grey[700] : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: enabled ? Colors.grey[400] : Colors.grey[300],
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}