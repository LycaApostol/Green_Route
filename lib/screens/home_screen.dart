import 'package:flutter/material.dart';
import '../widgets/mini_route_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, RouteBuddy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search here',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.green[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _modeCard(Icons.directions_bike, 'Cycling'),
                  const SizedBox(width: 12),
                  _modeCard(Icons.directions_walk, 'Walking'),
                ],
              ),
              const SizedBox(height: 18),
              Text('Tracking Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              miniRouteCard(title: 'Cycling', subtitle: '2.8 km • 40 min'),
              const SizedBox(height: 18),
              Text('Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _prefRow('Prioritize green spaces'),
              _prefRow('Safe cycling lanes only'),
              _prefRow('Scenic route preference'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 34, color: Colors.green[800]),
          const SizedBox(height: 8),
          Text(label),
        ]),
      ),
    );
  }

  Widget _prefRow(String text) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(text),
      trailing: Switch(value: true, onChanged: (v){}),
    );
  }
}
