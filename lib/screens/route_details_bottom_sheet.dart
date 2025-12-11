import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RouteDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> routeData;

  const RouteDetailsBottomSheet({
    super.key,
    required this.routeData,
  });

  @override
  State<RouteDetailsBottomSheet> createState() => _RouteDetailsBottomSheetState();
}

class _RouteDetailsBottomSheetState extends State<RouteDetailsBottomSheet> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final title = widget.routeData['title'] ?? 'Unknown Route';
    final subtitle = widget.routeData['subtitle'] ?? '';
    
    // Try to get addresses from top level first, then from meta
    String originAddress = widget.routeData['originAddress'] ?? 'Start Location';
    String destAddress = widget.routeData['destAddress'] ?? 'Destination';
    
    if ((originAddress == 'Start Location' || destAddress == 'Destination') && widget.routeData['meta'] != null) {
      final meta = widget.routeData['meta'] as Map<String, dynamic>;
      originAddress = meta['originAddress'] ?? originAddress;
      destAddress = meta['destAddress'] ?? destAddress;
    }
    
    final distance = widget.routeData['distance'] ?? 'N/A';
    final duration = widget.routeData['duration'] ?? 'N/A';
    final timestamp = widget.routeData['createdAt'];
    
    // Try to get coordinates from top level first, then from meta
    double? originLat = widget.routeData['originLat'] as double?;
    double? originLng = widget.routeData['originLng'] as double?;
    double? destLat = widget.routeData['destLat'] as double?;
    double? destLng = widget.routeData['destLng'] as double?;
    
    if ((originLat == null || originLng == null || destLat == null || destLng == null) && widget.routeData['meta'] != null) {
      final meta = widget.routeData['meta'] as Map<String, dynamic>;
      originLat ??= meta['originLat'] as double?;
      originLng ??= meta['originLng'] as double?;
      destLat ??= meta['destLat'] as double?;
      destLng ??= meta['destLng'] as double?;
    }
    
    // If coordinates still missing, try to extract from polylinePoints
    if (originLat == null || originLng == null || destLat == null || destLng == null) {
      List<dynamic>? polylinePoints = widget.routeData['polylinePoints'] as List<dynamic>?;
      
      // If not found at top level, try meta
      if (polylinePoints == null && widget.routeData['meta'] != null) {
        final meta = widget.routeData['meta'] as Map<String, dynamic>;
        polylinePoints = meta['polylinePoints'] as List<dynamic>?;
      }
      
      if (polylinePoints != null && polylinePoints.isNotEmpty) {
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
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Full screen map
          if (originLat != null && originLng != null && destLat != null && destLng != null)
            _buildFullMap(originLat, originLng, destLat, destLng),
          
          // Top header with close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom details panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Origin and Destination
                        _buildLocationItem(
                          Icons.radio_button_checked,
                          Colors.green[700]!,
                          'Start',
                          originAddress,
                          _formatTime(timestamp),
                        ),
                        
                        // Connecting line
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Container(
                            width: 2,
                            height: 30,
                            color: Colors.grey[300],
                          ),
                        ),
                        
                        _buildLocationItem(
                          Icons.location_on,
                          Colors.red,
                          'Destination',
                          destAddress,
                          _formatEndTime(timestamp, duration),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Stats row with green palette
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                Icons.straighten,
                                'Distance',
                                distance,
                                Colors.green[700]!,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                Icons.access_time,
                                'Duration',
                                duration,
                                Colors.grey[700]!,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullMap(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(originLat, originLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(destLat, destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    };

    // Calculate center and bounds
    final centerLat = (originLat + destLat) / 2;
    final centerLng = (originLng + destLng) / 2;

    final latDiff = (originLat - destLat).abs();
    final lngDiff = (originLng - destLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 12;
    if (maxDiff > 0.1) zoom = 10;
    if (maxDiff > 0.5) zoom = 8;
    if (maxDiff < 0.05) zoom = 13;

    // Build polyline - check both top level and meta
    final Set<Polyline> polylines = {};
    List<dynamic>? polylinePoints = widget.routeData['polylinePoints'] as List<dynamic>?;
    
    // If not found at top level, try meta
    if (polylinePoints == null && widget.routeData['meta'] != null) {
      final meta = widget.routeData['meta'] as Map<String, dynamic>;
      polylinePoints = meta['polylinePoints'] as List<dynamic>?;
    }
    
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
            width: 5,
          ),
        );
      } catch (e) {
        print('Error building polyline: $e');
      }
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: zoom,
      ),
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: true,
      onMapCreated: (controller) {
        _mapController = controller;
        
        // Fit bounds to show entire route
        if (polylinePoints != null && polylinePoints.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            final bounds = _calculateBounds(originLat, originLng, destLat, destLng);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100),
            );
          });
        }
      },
    );
  }

  LatLngBounds _calculateBounds(double lat1, double lng1, double lat2, double lng2) {
    final southwest = LatLng(
      lat1 < lat2 ? lat1 : lat2,
      lng1 < lng2 ? lng1 : lng2,
    );
    final northeast = LatLng(
      lat1 > lat2 ? lat1 : lat2,
      lng1 > lng2 ? lng1 : lng2,
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  Widget _buildLocationItem(
    IconData icon,
    Color color,
    String label,
    String address,
    String time,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color == Colors.green[700] ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color == Colors.green[700] ? Colors.green[200]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return DateFormat('h:mm a').format(dt).toUpperCase();
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  String _formatEndTime(dynamic ts, String duration) {
    try {
      if (ts is Timestamp && duration != 'N/A') {
        final dt = ts.toDate();
        // Parse duration string (e.g., "2 hr, 2 min" or "1 hr, 44 min" or "10 mins")
        final durationParts = duration.toLowerCase().split(',');
        int hours = 0;
        int minutes = 0;
        
        for (final part in durationParts) {
          if (part.contains('hr')) {
            hours = int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          } else if (part.contains('min')) {
            minutes = int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          }
        }
        
        // Handle single format like "10 mins"
        if (hours == 0 && minutes == 0 && duration.contains('min')) {
          minutes = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
        
        final endTime = dt.add(Duration(hours: hours, minutes: minutes));
        return DateFormat('h:mm a').format(endTime).toUpperCase();
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final now = DateTime.now();
        final diff = now.difference(dt);

        if (diff.inDays == 0) {
          return 'Today at ${DateFormat('h:mm a').format(dt)}';
        } else if (diff.inDays == 1) {
          return 'Yesterday at ${DateFormat('h:mm a').format(dt)}';
        } else if (diff.inDays < 7) {
          return '${DateFormat('EEEE').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
        } else {
          return DateFormat('MMM d, y \'at\' h:mm a').format(dt);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}