import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'route_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecentRoutesScreen extends StatelessWidget {
  const RecentRoutesScreen({super.key});
  static final FirestoreService _db = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(title: const Text('Recent Routes'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.streamRecentRoutes(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snap.data ?? [];
          if (data.isEmpty) return const Center(child: Text('No recent routes'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: data.length,
            itemBuilder: (ctx, i) {
              final r = data[i];
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(r['title'] ?? ''),
                subtitle: Text(r['subtitle'] ?? ''),
                trailing: Text(_formatTime(r['createdAt'])),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(title: r['title'] ?? '', subtitle: r['subtitle'] ?? '', routeData: r))),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return '${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
