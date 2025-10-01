import 'package:flutter/material.dart';
class PrivacySettings extends StatelessWidget {
  const PrivacySettings({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Privacy & Security')), body: Center(child: Text('Privacy settings')));
  }
}
