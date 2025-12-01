import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'route_detail_screen.dart';

const String googleApiKey = "";

class RouteListScreen extends StatefulWidget {
  final maps.LatLng fromLocation;
  final maps.LatLng toLocation;
  final String fromAddress;
  final String toAddress;

  const RouteListScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.fromAddress,
    required this.toAddress,
  });

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  maps.GoogleMapController? mapController;
  List<RouteOption> routeOptions = [];
  bool isLoading = true;
  String? errorMessage;
  int? selectedRouteIndex;
  int? shortestRouteIndex;

  Set<maps.Marker> markers = {};
  Map<maps.PolylineId, maps.Polyline> polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _fetchRoutes();
  }

  void _initializeMap() {
    markers = {
      maps.Marker(
        markerId: const maps.MarkerId('start'),
        position: widget.fromLocation,
        icon: maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueGreen),
        infoWindow: maps.InfoWindow(
          title: 'Start',
          snippet: widget.fromAddress,
        ),
      ),
      maps.Marker(
        markerId: const maps.MarkerId('end'),
        position: widget.toLocation,
        icon: maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueRed),
        infoWindow: maps.InfoWindow(
          title: 'Destination',
          snippet: widget.toAddress,
        ),
      ),
    };
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch walking routes
      final walkingRoutes = await _fetchRoutesForMode('walking');
      
      // Fetch cycling routes
      final cyclingRoutes = await _fetchRoutesForMode('bicycling');

      // Combine and limit to 3 routes
      List<RouteOption> allRoutes = [...walkingRoutes, ...cyclingRoutes];
      
      if (allRoutes.isEmpty) {
        setState(() {
          errorMessage = 'No walking or cycling routes found between these locations.';
          isLoading = false;
        });
        return;
      }

      // Sort by distance (shortest first) and take top 3
      allRoutes.sort((a, b) => a.distanceValue.compareTo(b.distanceValue));
      allRoutes = allRoutes.take(3).toList();

      // Re-index routes
      for (int i = 0; i < allRoutes.length; i++) {
        allRoutes[i] = allRoutes[i].copyWith(routeIndex: i);
      }

      // Find shortest route (first one after sorting)
      int shortest = 0;

      setState(() {
        routeOptions = allRoutes;
        shortestRouteIndex = shortest;
        isLoading = false;
        if (allRoutes.isNotEmpty) {
          _selectRoute(shortest);
        }
      });
    } catch (e) {
      print('Error fetching routes: $e');
      setState(() {
        errorMessage = 'Failed to load routes. Please check your internet connection.';
        isLoading = false;
      });
    }
  }

  Future<List<RouteOption>> _fetchRoutesForMode(String mode) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${widget.fromLocation.latitude},${widget.fromLocation.longitude}'
          '&destination=${widget.toLocation.latitude},${widget.toLocation.longitude}'
          '&mode=$mode'
          '&alternatives=true'
          '&key=$googleApiKey';

      print('Fetching $mode routes from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('API Status for $mode: ${data['status']}');
        
        if (data['status'] == 'OK') {
          return (data['routes'] as List)
              .asMap()
              .entries
              .map((entry) => RouteOption.fromJson(entry.value, entry.key, mode))
              .toList();
        }
      }
    } catch (e) {
      print('Error fetching $mode routes: $e');
    }
    return [];
  }

  void _selectRoute(int index) {
    setState(() {
      selectedRouteIndex = index;
      _drawRouteOnMap(routeOptions[index]);
    });

    if (mapController != null) {
      _fitMapToRoute(routeOptions[index]);
    }
  }

  void _navigateToDetail(int index) {
    final route = routeOptions[index];
    final isRecommended = shortestRouteIndex == index;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailScreen(
          title: '${route.mode == 'walking' ? 'Walking' : 'Cycling'} Route',
          subtitle: '${widget.fromAddress} to ${widget.toAddress}',
          routeData: {
            'mode': route.mode,
            'distance': route.distance,
            'duration': route.duration,
            'isRecommended': isRecommended,
            'polylinePoints': route.polylinePoints
                .map((point) => {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                })
                .toList(),
            'steps': route.steps
                .map((step) => {
                  'instruction': step.instruction,
                  'duration': step.duration,
                  'distance': step.distance,
                })
                .toList(),
          },
        ),
      ),
    );
  }

  void _drawRouteOnMap(RouteOption route) {
    final polylineId = maps.PolylineId('route_${route.routeIndex}');
    
    final polyline = maps.Polyline(
      polylineId: polylineId,
      points: route.polylinePoints,
      color: route.mode == 'walking' ? Colors.blue : Colors.orange,
      width: 5,
      startCap: maps.Cap.roundCap,
      endCap: maps.Cap.roundCap,
    );

    setState(() {
      polylines.clear();
      polylines[polylineId] = polyline;
    });
  }

  void _fitMapToRoute(RouteOption route) {
    if (mapController == null || route.polylinePoints.isEmpty) return;

    double minLat = route.polylinePoints[0].latitude;
    double maxLat = route.polylinePoints[0].latitude;
    double minLng = route.polylinePoints[0].longitude;
    double maxLng = route.polylinePoints[0].longitude;

    for (var point in route.polylinePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = maps.LatLngBounds(
      southwest: maps.LatLng(minLat, minLng),
      northeast: maps.LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(
      maps.CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Options'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Map Section
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: maps.GoogleMap(
              initialCameraPosition: maps.CameraPosition(
                target: widget.fromLocation,
                zoom: 13,
              ),
              markers: markers,
              polylines: Set<maps.Polyline>.of(polylines.values),
              onMapCreated: (controller) {
                mapController = controller;
                if (routeOptions.isNotEmpty && selectedRouteIndex != null) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _fitMapToRoute(routeOptions[selectedRouteIndex!]);
                  });
                }
              },
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),

          // Route List Section
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Finding best routes...'),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _fetchRoutes,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : routeOptions.isEmpty
                        ? const Center(
                            child: Text(
                              'No routes available',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: routeOptions.length,
                            itemBuilder: (context, index) {
                              final route = routeOptions[index];
                              final isSelected = selectedRouteIndex == index;
                              final isRecommended = shortestRouteIndex == index;

                              return Card(
                                elevation: isSelected ? 4 : 2,
                                color: isSelected ? Colors.green[50] : Colors.white,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? Colors.green : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _selectRoute(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: route.mode == 'walking' 
                                                    ? Colors.blue[100] 
                                                    : Colors.orange[100],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                route.mode == 'walking' 
                                                    ? Icons.directions_walk 
                                                    : Icons.directions_bike,
                                                color: route.mode == 'walking' 
                                                    ? Colors.blue[700] 
                                                    : Colors.orange[700],
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        route.mode == 'walking' ? 'Walking' : 'Cycling',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: route.mode == 'walking' 
                                                              ? Colors.blue[700] 
                                                              : Colors.orange[700],
                                                        ),
                                                      ),
                                                      if (isRecommended) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber,
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.star,
                                                                size: 14,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              const Text(
                                                                'Shortest',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                                            const SizedBox(width: 8),
                                            Text(
                                              route.duration,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Icon(Icons.straighten, size: 20, color: Colors.grey[600]),
                                            const SizedBox(width: 8),
                                            Text(
                                              route.distance,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () => _navigateToDetail(index),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSelected 
                                                  ? Colors.green[700] 
                                                  : Colors.grey[300],
                                              foregroundColor: isSelected 
                                                  ? Colors.white 
                                                  : Colors.grey[700],
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'View Details',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class RouteOption {
  final int routeIndex;
  final String duration;
  final String distance;
  final int distanceValue;
  final List<maps.LatLng> polylinePoints;
  final List<RouteStep> steps;
  final String mode;

  RouteOption({
    required this.routeIndex,
    required this.duration,
    required this.distance,
    required this.distanceValue,
    required this.polylinePoints,
    required this.steps,
    required this.mode,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json, int index, String mode) {
    final leg = json['legs'][0];
    
    // Decode polyline
    final polylinePoints = PolylinePoints()
        .decodePolyline(json['overview_polyline']['points'])
        .map((point) => maps.LatLng(point.latitude, point.longitude))
        .toList();

    // Parse steps
    final steps = (leg['steps'] as List)
        .map((step) => RouteStep.fromJson(step))
        .toList();

    return RouteOption(
      routeIndex: index,
      duration: leg['duration']['text'] ?? 'N/A',
      distance: leg['distance']['text'] ?? 'N/A',
      distanceValue: leg['distance']['value'] ?? 0,
      polylinePoints: polylinePoints,
      steps: steps,
      mode: mode,
    );
  }

  RouteOption copyWith({
    int? routeIndex,
    String? duration,
    String? distance,
    int? distanceValue,
    List<maps.LatLng>? polylinePoints,
    List<RouteStep>? steps,
    String? mode,
  }) {
    return RouteOption(
      routeIndex: routeIndex ?? this.routeIndex,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      distanceValue: distanceValue ?? this.distanceValue,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      steps: steps ?? this.steps,
      mode: mode ?? this.mode,
    );
  }
}

class RouteStep {
  final String instruction;
  final String duration;
  final String distance;

  RouteStep({
    required this.instruction,
    required this.duration,
    required this.distance,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    // Clean HTML instructions
    String instruction = json['html_instructions']
        ?.replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"') ?? 'Continue';

    return RouteStep(
      instruction: instruction,
      duration: json['duration']?['text'] ?? 'N/A',
      distance: json['distance']?['text'] ?? 'N/A',
    );
  }
}