import 'package:flutter/material.dart';
class NotificationsSettings extends StatelessWidget {
  const NotificationsSettings({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Notifications')), body: Center(child: Text('Notification preferences')));
  }
}
