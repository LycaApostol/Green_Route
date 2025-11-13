import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

const String googleApiKey = "AIzaSyAdys3eRrtBjvpB9WUB-MqhGxs0dtYvfNI";

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
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${widget.fromLocation.latitude},${widget.fromLocation.longitude}'
          '&destination=${widget.toLocation.latitude},${widget.toLocation.longitude}'
          '&mode=transit'
          '&alternatives=true'
          '&key=$googleApiKey';

      print('Fetching routes from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('API Status: ${data['status']}');
        
        if (data['status'] == 'OK') {
          final routes = (data['routes'] as List)
              .asMap()
              .entries
              .map((entry) => RouteOption.fromJson(entry.value, entry.key))
              .toList();

          setState(() {
            routeOptions = routes;
            isLoading = false;
            if (routes.isNotEmpty) {
              _selectRoute(0);
            }
          });
        } else if (data['status'] == 'ZERO_RESULTS') {
          setState(() {
            errorMessage = 'No transit routes found between these locations. Transit may not be available.';
            isLoading = false;
          });
        } else if (data['status'] == 'NOT_FOUND') {
          setState(() {
            errorMessage = 'One or both locations could not be found.';
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Error: ${data['status']}\n${data['error_message'] ?? ''}';
            isLoading = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching routes: $e');
      setState(() {
        errorMessage = 'Failed to load routes. Please check your internet connection.';
        isLoading = false;
      });
    }
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

  void _drawRouteOnMap(RouteOption route) {
    final polylineId = maps.PolylineId('route_${route.routeIndex}');
    
    final polyline = maps.Polyline(
      polylineId: polylineId,
      points: route.polylinePoints,
      color: Colors.blue,
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

                              return Card(
                                elevation: isSelected ? 8 : 2,
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
                                                color: Colors.green[100],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.directions_transit,
                                                color: Colors.green[700],
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Route ${index + 1}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isSelected)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[700],
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'Selected',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                                        if (route.steps.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(Icons.list, size: 18, color: Colors.grey[700]),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Directions (${route.steps.length} steps)',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ...route.steps.asMap().entries.map((entry) {
                                            final stepIndex = entry.key;
                                            final step = entry.value;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[100],
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${stepIndex + 1}',
                                                        style: TextStyle(
                                                          color: Colors.green[700],
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              _getIconForTravelMode(step.travelMode),
                                                              size: 18,
                                                              color: Colors.grey[600],
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              step.travelMode.toUpperCase(),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.grey[600],
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Text(
                                                              '${step.duration} • ${step.distance}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          step.instruction,
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
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

  IconData _getIconForTravelMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
        return Icons.directions_transit;
      case 'driving':
        return Icons.directions_car;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.navigation;
    }
  }
}

class RouteOption {
  final int routeIndex;
  final String duration;
  final String distance;
  final List<maps.LatLng> polylinePoints;
  final List<RouteStep> steps;

  RouteOption({
    required this.routeIndex,
    required this.duration,
    required this.distance,
    required this.polylinePoints,
    required this.steps,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json, int index) {
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
      polylinePoints: polylinePoints,
      steps: steps,
    );
  }
}

class RouteStep {
  final String instruction;
  final String duration;
  final String distance;
  final String travelMode;

  RouteStep({
    required this.instruction,
    required this.duration,
    required this.distance,
    required this.travelMode,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    // Clean HTML instructions
    String instruction = json['html_instructions']
        ?.replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"') ?? 'Continue';

    // Add transit details if available
    if (json['transit_details'] != null) {
      final transit = json['transit_details'];
      final line = transit['line'];
      final vehicleType = line['vehicle']?['name'] ?? 'Transit';
      final lineName = line['short_name'] ?? line['name'] ?? '';
      
      if (lineName.isNotEmpty) {
        instruction = '$vehicleType $lineName: $instruction';
      }
      
      // Add departure and arrival stops if available
      final departureStop = transit['departure_stop']?['name'];
      final arrivalStop = transit['arrival_stop']?['name'];
      
      if (departureStop != null && arrivalStop != null) {
        instruction += '\nFrom: $departureStop\nTo: $arrivalStop';
      }
    }

    return RouteStep(
      instruction: instruction,
      duration: json['duration']?['text'] ?? 'N/A',
      distance: json['distance']?['text'] ?? 'N/A',
      travelMode: json['travel_mode'] ?? 'WALKING',
    );
  }
}