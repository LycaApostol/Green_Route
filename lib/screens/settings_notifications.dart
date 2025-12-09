import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettings extends StatefulWidget {
  const NotificationsSettings({super.key});

  @override
  State<NotificationsSettings> createState() => _NotificationsSettingsState();
}

class _NotificationsSettingsState extends State<NotificationsSettings> {
  bool _pushNotifications = true;
  bool _weatherAlerts = true;
  bool _severeWeatherAlerts = true;
  bool _dailyForecast = false;
  bool _rainAlerts = true;
  bool _temperatureAlerts = false;
  String _notificationTime = '08:00';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _weatherAlerts = prefs.getBool('weather_alerts') ?? true;
      _severeWeatherAlerts = prefs.getBool('severe_weather_alerts') ?? true;
      _dailyForecast = prefs.getBool('daily_forecast') ?? false;
      _rainAlerts = prefs.getBool('rain_alerts') ?? true;
      _temperatureAlerts = prefs.getBool('temperature_alerts') ?? false;
      _notificationTime = prefs.getString('notification_time') ?? '08:00';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', _pushNotifications);
    await prefs.setBool('weather_alerts', _weatherAlerts);
    await prefs.setBool('severe_weather_alerts', _severeWeatherAlerts);
    await prefs.setBool('daily_forecast', _dailyForecast);
    await prefs.setBool('rain_alerts', _rainAlerts);
    await prefs.setBool('temperature_alerts', _temperatureAlerts);
    await prefs.setString('notification_time', _notificationTime);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_notificationTime.split(':')[0]),
        minute: int.parse(_notificationTime.split(':')[1]),
      ),
    );

    if (picked != null) {
      setState(() {
        _notificationTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.green[900],
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green[900],
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18.0),
          children: [
            const Text(
              'Notification Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your notification preferences',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Master Toggle
            _buildSection(
              title: 'General',
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Enable all notifications',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                      if (!value) {
                        _weatherAlerts = false;
                        _severeWeatherAlerts = false;
                        _dailyForecast = false;
                        _rainAlerts = false;
                        _temperatureAlerts = false;
                      }
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Weather Alerts Section
            _buildSection(
              title: 'Weather Alerts',
              children: [
                _buildSwitchTile(
                  icon: Icons.cloud,
                  title: 'General Weather Alerts',
                  subtitle: 'Get notified about weather changes',
                  value: _weatherAlerts,
                  enabled: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _weatherAlerts = value);
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.warning_amber,
                  title: 'Severe Weather Alerts',
                  subtitle: 'Critical weather warnings',
                  value: _severeWeatherAlerts,
                  enabled: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _severeWeatherAlerts = value);
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.umbrella,
                  title: 'Rain Alerts',
                  subtitle: 'Notify when rain is expected',
                  value: _rainAlerts,
                  enabled: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _rainAlerts = value);
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.thermostat,
                  title: 'Temperature Alerts',
                  subtitle: 'Notify about extreme temperatures',
                  value: _temperatureAlerts,
                  enabled: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _temperatureAlerts = value);
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Daily Forecast Section
            _buildSection(
              title: 'Daily Updates',
              children: [
                _buildSwitchTile(
                  icon: Icons.wb_sunny,
                  title: 'Daily Forecast',
                  subtitle: 'Receive daily weather forecast',
                  value: _dailyForecast,
                  enabled: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _dailyForecast = value);
                    _saveSettings();
                  },
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _dailyForecast && _pushNotifications
                        ? Colors.green[50]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    enabled: _dailyForecast && _pushNotifications,
                    leading: Icon(
                      Icons.access_time,
                      color: _dailyForecast && _pushNotifications
                          ? Colors.green[700]
                          : Colors.grey,
                    ),
                    title: const Text('Notification Time'),
                    subtitle: Text(_notificationTime),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: _dailyForecast && _pushNotifications
                          ? Colors.grey[600]
                          : Colors.grey[300],
                    ),
                    onTap: _dailyForecast && _pushNotifications
                        ? _selectTime
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Test Notification Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pushNotifications
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Send Test Notification'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: _pushNotifications ? Colors.green : Colors.grey,
                  ),
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
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: enabled ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: enabled ? Colors.green[700] : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: enabled ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        value: value,
        activeThumbColor: Colors.green,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}