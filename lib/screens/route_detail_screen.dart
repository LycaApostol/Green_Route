import 'package:flutter/material.dart';
import 'map_route_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class RouteDetailScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic>? routeData;
  const RouteDetailScreen({super.key, required this.title, required this.subtitle, this.routeData});

  static final FirestoreService _db = FirestoreService();

  Future<void> _onStart(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Save to recent routes
      final route = {
        'title': title,
        'subtitle': subtitle,
        'meta': routeData ?? {},
      };
      await _db.addRecentRoute(uid, route);
    }
    // navigate to map screen, passing routeData if needed
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MapRouteScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subtitle, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 12),
            Container(height: 180, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[200]), child: const Center(child: Text('Map preview (placeholder)'))),
            const SizedBox(height: 18),
            Text('85% Green Score', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              _statCard('DISTANCE', '4.1 km'),
              const SizedBox(width: 12),
              _statCard('EST. TIME', '55 min'),
            ]),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _onStart(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size.fromHeight(48)),
              child: const Text('Start'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
        child: Column(children: [Text(title, style: TextStyle(color: Colors.grey[700])), const SizedBox(height: 8), Text(val, style: TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}
