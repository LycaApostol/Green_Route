import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_details_bottom_sheet.dart';

class RecentRoutesScreen extends StatelessWidget {
  const RecentRoutesScreen({super.key});
  static final FirestoreService _db = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    print('Recent Routes - Building for user: $uid');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recent Routes',
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
        stream: _db.streamRecentRoutes(uid),
        builder: (context, snap) {
          print('Recent Routes - Stream state: ${snap.connectionState}');
          print('Recent Routes - Has data: ${snap.hasData}');
          print('Recent Routes - Data length: ${snap.data?.length}');
          
          if (snap.hasData && snap.data!.isNotEmpty) {
            print('Recent Routes - First route data: ${snap.data!.first}');
          }
          
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: CircularProgressIndicator(
                  color: Colors.green,
                ),
              ),
            );
          }
          
          final data = snap.data ?? [];
          
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No recent routes',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start navigating to see your history',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            itemCount: data.length,
            itemBuilder: (ctx, i) {
              final r = data[i];
              return _buildRouteCard(context, r, uid);
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteRoute(BuildContext context, String uid, String routeId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Route',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete this route from your history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _db.removeRecentRoute(uid, routeId);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[900], size: 20),
                  const SizedBox(width: 8),
                  const Text('Route deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green[100],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error deleting route: $e')),
                ],
              ),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Widget _buildRouteCard(BuildContext context, Map<String, dynamic> route, String uid) {
    final title = route['title'] ?? 'Unknown Route';
    final timestamp = route['createdAt'];
    final distance = route['distance'] ?? 'N/A';
    final duration = route['duration'] ?? 'N/A';
    final routeId = route['id'] ?? '';
    
    // Try to get coordinates from top level first, then from meta
    double? originLat = route['originLat'] as double?;
    double? originLng = route['originLng'] as double?;
    double? destLat = route['destLat'] as double?;
    double? destLng = route['destLng'] as double?;
    List<dynamic>? polylinePoints = route['polylinePoints'] as List<dynamic>?;
    
    // If not found at top level, try meta
    if ((originLat == null || originLng == null || destLat == null || destLng == null) && route['meta'] != null) {
      final meta = route['meta'] as Map<String, dynamic>;
      originLat ??= meta['originLat'] as double?;
      originLng ??= meta['originLng'] as double?;
      destLat ??= meta['destLat'] as double?;
      destLng ??= meta['destLng'] as double?;
      polylinePoints ??= meta['polylinePoints'] as List<dynamic>?;
    }
    
    // If coordinates still missing but we have polylinePoints, extract from there
    if ((originLat == null || originLng == null || destLat == null || destLng == null) && 
        polylinePoints != null && polylinePoints.isNotEmpty) {
      try {
        final firstPoint = polylinePoints.first;
        final lastPoint = polylinePoints.last;
        
        originLat ??= (firstPoint['lat'] ?? firstPoint['latitude']) as double?;
        originLng ??= (firstPoint['lng'] ?? firstPoint['longitude']) as double?;
        destLat ??= (lastPoint['lat'] ?? lastPoint['latitude']) as double?;
        destLng ??= (lastPoint['lng'] ?? lastPoint['longitude']) as double?;
      } catch (e) {
        print('Error extracting coordinates from polyline: $e');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteDetailsBottomSheet(routeData: route),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Preview Section
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: SizedBox(
                height: 140,
                child: (originLat != null && originLng != null && destLat != null && destLng != null)
                  ? _buildMapPreview(
                      originLat, 
                      originLng, 
                      destLat, 
                      destLng,
                      polylinePoints,
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Left side - Title and stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              duration,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Right side - Time badge and menu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatTimeAgo(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[900],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        offset: const Offset(0, 40),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteRoute(context, uid, routeId);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.red[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
    List<dynamic>? polylinePoints,
  ) {
    // Calculate center point between origin and destination
    final centerLat = (originLat + destLat) / 2;
    final centerLng = (originLng + destLng) / 2;

    // Calculate appropriate zoom level based on distance
    final latDiff = (originLat - destLat).abs();
    final lngDiff = (originLng - destLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 12;
    if (maxDiff > 0.1) zoom = 10;
    if (maxDiff > 0.5) zoom = 8;
    if (maxDiff < 0.05) zoom = 13;

    // Build polyline if points are available
    final Set<Polyline> polylines = {};
    if (polylinePoints != null && polylinePoints.isNotEmpty) {
      try {
        // Handle both {lat, lng} and {latitude, longitude} formats
        final List<LatLng> points = polylinePoints.map((p) {
          final lat = (p['lat'] ?? p['latitude']) as double;
          final lng = (p['lng'] ?? p['longitude']) as double;
          return LatLng(lat, lng);
        }).toList();

        polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.green[700]!,
            width: 4,
          ),
        );
      } catch (e) {
        print('Error building polyline: $e');
      }
    }

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(originLat, originLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(destLat, destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: zoom,
      ),
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      liteModeEnabled: true,
      onMapCreated: (GoogleMapController controller) {
        if (polylinePoints != null && polylinePoints.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 100), () {
            try {
              final bounds = LatLngBounds(
                southwest: LatLng(
                  originLat < destLat ? originLat : destLat,
                  originLng < destLng ? originLng : destLng,
                ),
                northeast: LatLng(
                  originLat > destLat ? originLat : destLat,
                  originLng > destLng ? originLng : destLng,
                ),
              );
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 50),
              );
            } catch (e) {
              print('Error fitting bounds: $e');
            }
          });
        }
      },
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        final now = DateTime.now();
        final diff = now.difference(dt);

        if (diff.inMinutes < 1) {
          return 'Just now';
        } else if (diff.inMinutes < 60) {
          return '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          return '${diff.inHours}h ago';
        } else if (diff.inDays == 1) {
          return 'Yesterday';
        } else if (diff.inDays < 7) {
          return '${diff.inDays}d ago';
        } else {
          return DateFormat('MMM d').format(dt);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}