import 'package:flutter/material.dart';
import 'route_detail_screen.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({super.key});
  final List<Map<String,String>> _results = const [
    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (ctx, i) {
          final r = _results[i];
          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(r['title']!),
            subtitle: Text(r['subtitle']!),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailScreen(title: r['title']!, subtitle: r['subtitle']!))),
          );
        },
        separatorBuilder: (_,__) => const SizedBox(height: 8),
        itemCount: _results.length,
      ),
    );
  }
}
