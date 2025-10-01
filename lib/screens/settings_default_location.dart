import 'package:flutter/material.dart';
class DefaultLocationSettings extends StatelessWidget {
  const DefaultLocationSettings({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Default Location')), body: Center(child: Text('Default location settings')));
  }
}
