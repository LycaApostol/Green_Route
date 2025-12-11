import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'route_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  static final FirestoreService _db = FirestoreService();

  Future<void> _removeFavorite(BuildContext context, String uid, String favoriteId, String title) async {
    try {
      await _db.removeFavorite(uid, favoriteId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite_border, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Removed "$title" from favorites'),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing favorite: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  // Helper method to normalize route data format - runs in background
  Future<Map<String, dynamic>> _normalizeRouteDataAsync(Map<String, dynamic> favorite) async {
    // Run heavy processing in a separate isolate context
    return await Future.microtask(() {
      final routeData = Map<String, dynamic>.from(favorite);
      
      // Check if polylinePoints exists and normalize the format
      if (routeData['polylinePoints'] != null) {
        final points = routeData['polylinePoints'] as List<dynamic>;
        
        // Normalize to latitude/longitude format if needed
        routeData['polylinePoints'] = points.map((point) {
          if (point is Map<String, dynamic>) {
            // Handle both lat/lng and latitude/longitude formats
            return {
              'latitude': point['latitude'] ?? point['lat'],
              'longitude': point['longitude'] ?? point['lng'],
            };
          }
          return point;
        }).toList();
      }
      
      return routeData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.streamFavorites(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading favorites',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          
          final data = snap.data ?? [];
          
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save routes to quickly access them later',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: data.length,
            itemBuilder: (ctx, i) {
              final r = data[i];
              return _buildFavoriteItem(context, r, uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteItem(
    BuildContext context,
    Map<String, dynamic> favorite,
    String uid,
  ) {
    final title = favorite['title'] ?? 'Unknown Location';
    final subtitle = favorite['subtitle'] ?? '';
    final favoriteId = favorite['id'] ?? '';

    return InkWell(
      onTap: () async {
        // Show loading indicator while processing
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          // Process data asynchronously to avoid blocking UI
          final normalizedData = await _normalizeRouteDataAsync(favorite);
          
          if (!context.mounted) return;
          
          // Close loading dialog
          Navigator.pop(context);
          
          // Navigate to route detail
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RouteDetailScreen(
                title: title,
                subtitle: subtitle,
                routeData: normalizedData,
              ),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          
          // Close loading dialog
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading route: $e'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            // Heart icon - Now tappable to remove
            InkWell(
              onTap: () => _removeFavorite(context, uid, favoriteId, title),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8F5E9), width: 1.5),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Location details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Share button
            IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: Colors.grey[700],
                size: 20,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Share feature coming soon!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}