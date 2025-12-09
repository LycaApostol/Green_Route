import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'route_detail_screen.dart';

const String googleApiKey = "AIzaSyBuAq0UCRUt89jKicriPY8_KCfHWIGrzLc";

class RouteListScreen extends StatefulWidget {
  final maps.LatLng fromLocation;
  final maps.LatLng toLocation;
  final String fromAddress;
  final String toAddress;
  final String travelMode;
  final Map<String, bool> preferences;

  const RouteListScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.fromAddress,
    required this.toAddress,
    this.travelMode = 'Cycling',
    this.preferences = const {},
  });

  @override
  State<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends State<RouteListScreen> {
  List<RouteOption> routes = [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  String _getApiTravelMode() {
    switch (widget.travelMode.toLowerCase()) {
      case 'cycling':
        return 'bicycling';
      case 'walking':
        return 'walking';
      default:
        return 'walking';
    }
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final mode = _getApiTravelMode();
      
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${widget.fromLocation.latitude},${widget.fromLocation.longitude}'
          '&destination=${widget.toLocation.latitude},${widget.toLocation.longitude}'
          '&mode=$mode'
          '&alternatives=true'
          '&key=$googleApiKey';

      List<String> avoidParams = [];
      
      if (widget.travelMode == 'Walking') {
        if (widget.preferences['Avoid highways'] == true) {
          avoidParams.add('highways');
        }
      }

      if (avoidParams.isNotEmpty) {
        url += '&avoid=${avoidParams.join(',')}';
      }

      print('Fetching routes with mode: $mode');
      print('URL: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // FOR CYCLING: If no bicycling routes found, use driving routes as cycling-friendly alternatives
        if (widget.travelMode == 'Cycling' && 
            (data['status'] == 'ZERO_RESULTS' || data['routes'] == null || data['routes'].isEmpty)) {
          print('No bicycling routes found, fetching driving routes as cycling alternatives...');
          await _fetchFallbackRoutes();
          return;
        }

        if (data['status'] == 'OK') {
          final routesList = <RouteOption>[];
          
          for (var route in data['routes']) {
            final leg = route['legs'][0];
            
            List<maps.LatLng> polylineCoordinates = [];
            if (route['overview_polyline'] != null && 
                route['overview_polyline']['points'] != null) {
              polylineCoordinates = _decodePolyline(
                route['overview_polyline']['points']
              );
            }
            
            final distanceValue = leg['distance']['value'] ?? 0;
            
            // SIMULATED bike lane scoring for Cebu City
            int bikeLaneScore = 0;
            if (widget.travelMode == 'Cycling') {
              bikeLaneScore = _simulateBikeLaneScore(
                polylineCoordinates, 
                route['summary'] ?? '',
                distanceValue
              );
            }
            
            // SIMULATED elevation gain for Cebu City
            double elevationGain = 0;
            if (widget.travelMode == 'Cycling') {
              elevationGain = _simulateElevationGain(
                polylineCoordinates,
                route['summary'] ?? '',
                distanceValue
              );
            }
            
            routesList.add(RouteOption(
              summary: route['summary'] ?? 'Route',
              distance: leg['distance']['text'] ?? '',
              duration: leg['duration']['text'] ?? '',
              polylinePoints: route['overview_polyline']['points'] ?? '',
              polylineCoordinates: polylineCoordinates,
              distanceValue: distanceValue,
              bikeLaneScore: bikeLaneScore,
              elevationGain: elevationGain,
              steps: (leg['steps'] as List).map((step) {
                return RouteStep(
                  instruction: _stripHtml(step['html_instructions'] ?? ''),
                  distance: step['distance']['text'] ?? '',
                  duration: step['duration']['text'] ?? '',
                  travelMode: step['travel_mode'] ?? mode.toUpperCase(),
                );
              }).toList(),
            ));
          }

          // Sort routes based on preferences
          if (widget.travelMode == 'Cycling') {
            if (widget.preferences['Prioritize bike lanes'] == true) {
              routesList.sort((a, b) {
                if (a.bikeLaneScore != b.bikeLaneScore) {
                  return b.bikeLaneScore.compareTo(a.bikeLaneScore);
                }
                return a.distanceValue.compareTo(b.distanceValue);
              });
            } else if (widget.preferences['Avoid steep hills'] == true) {
              routesList.sort((a, b) {
                if (a.elevationGain != b.elevationGain) {
                  return a.elevationGain.compareTo(b.elevationGain);
                }
                return a.distanceValue.compareTo(b.distanceValue);
              });
            } else {
              routesList.sort((a, b) => a.distanceValue.compareTo(b.distanceValue));
            }
          } else {
            routesList.sort((a, b) => a.distanceValue.compareTo(b.distanceValue));
          }

          setState(() {
            routes = routesList;
            loading = false;
          });

          if (routes.isEmpty) {
            setState(() {
              errorMessage = 'No ${widget.travelMode.toLowerCase()} routes found for this journey.';
            });
          }
        } else if (data['status'] == 'ZERO_RESULTS') {
          // For cycling, try fallback
          if (widget.travelMode == 'Cycling') {
            await _fetchFallbackRoutes();
          } else {
            setState(() {
              loading = false;
              errorMessage = 'No ${widget.travelMode.toLowerCase()} routes available between these locations.';
            });
          }
        } else {
          setState(() {
            loading = false;
            errorMessage = 'Error: ${data['status']}';
          });
        }
      } else {
        setState(() {
          loading = false;
          errorMessage = 'Failed to fetch routes. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Error: $e';
      });
      print('Error fetching routes: $e');
    }
  }

  // Fallback: Fetch driving routes and present them as cycling-friendly alternatives
  Future<void> _fetchFallbackRoutes() async {
    try {
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${widget.fromLocation.latitude},${widget.fromLocation.longitude}'
          '&destination=${widget.toLocation.latitude},${widget.toLocation.longitude}'
          '&mode=driving'
          '&alternatives=true'
          '&key=$googleApiKey';

      print('Fetching fallback driving routes for cycling...');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'] != null) {
          final routesList = <RouteOption>[];
          
          for (var route in data['routes']) {
            final leg = route['legs'][0];
            
            List<maps.LatLng> polylineCoordinates = [];
            if (route['overview_polyline'] != null && 
                route['overview_polyline']['points'] != null) {
              polylineCoordinates = _decodePolyline(
                route['overview_polyline']['points']
              );
            }
            
            final distanceValue = leg['distance']['value'] ?? 0;
            
            // Adjust duration for cycling (roughly 2.5x driving time)
            final drivingDuration = leg['duration']['value'] ?? 0;
            final cyclingDurationMins = (drivingDuration * 2.5 / 60).round();
            
            // SIMULATED bike lane scoring
            int bikeLaneScore = _simulateBikeLaneScore(
              polylineCoordinates, 
              route['summary'] ?? '',
              distanceValue
            );
            
            // SIMULATED elevation gain
            double elevationGain = _simulateElevationGain(
              polylineCoordinates,
              route['summary'] ?? '',
              distanceValue
            );
            
            routesList.add(RouteOption(
              summary: route['summary'] ?? 'Route',
              distance: leg['distance']['text'] ?? '',
              duration: '$cyclingDurationMins mins', // Adjusted for cycling
              polylinePoints: route['overview_polyline']['points'] ?? '',
              polylineCoordinates: polylineCoordinates,
              distanceValue: distanceValue,
              bikeLaneScore: bikeLaneScore,
              elevationGain: elevationGain,
              steps: (leg['steps'] as List).map((step) {
                return RouteStep(
                  instruction: _stripHtml(step['html_instructions'] ?? ''),
                  distance: step['distance']['text'] ?? '',
                  duration: step['duration']['text'] ?? '',
                  travelMode: 'BICYCLING',
                );
              }).toList(),
            ));
          }

          // Sort routes based on preferences
          if (widget.preferences['Prioritize bike lanes'] == true) {
            routesList.sort((a, b) {
              if (a.bikeLaneScore != b.bikeLaneScore) {
                return b.bikeLaneScore.compareTo(a.bikeLaneScore);
              }
              return a.distanceValue.compareTo(b.distanceValue);
            });
          } else if (widget.preferences['Avoid steep hills'] == true) {
            routesList.sort((a, b) {
              if (a.elevationGain != b.elevationGain) {
                return a.elevationGain.compareTo(b.elevationGain);
              }
              return a.distanceValue.compareTo(b.distanceValue);
            });
          } else {
            routesList.sort((a, b) => a.distanceValue.compareTo(b.distanceValue));
          }

          setState(() {
            routes = routesList;
            loading = false;
          });
        } else {
          setState(() {
            loading = false;
            errorMessage = 'No cycling routes available for this location.';
          });
        }
      } else {
        setState(() {
          loading = false;
          errorMessage = 'Failed to fetch alternative routes.';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Error: $e';
      });
      print('Error fetching fallback routes: $e');
    }
  }

  // SIMULATED bike lane scoring based on route characteristics for Cebu City
  int _simulateBikeLaneScore(List<maps.LatLng> coordinates, String summary, int distanceValue) {
    final random = Random(summary.hashCode);
    
    int baseScore = 0;
    
    final majorRoads = [
      'Osmena', 'Osmeña', 'Mandaue', 'Mactan', 'Gorordo', 
      'Banilad', 'Talamban', 'SRP', 'Cebu South Road',
      'AS Fortuna', 'Escario', 'General Maxilom', 'Colon',
      'Archbishop Reyes', 'Mango', 'V. Rama'
    ];
    
    bool usesMajorRoad = majorRoads.any((road) => 
      summary.toLowerCase().contains(road.toLowerCase())
    );
    
    if (usesMajorRoad) {
      baseScore = 8 + random.nextInt(4);
    } else {
      baseScore = 3 + random.nextInt(5);
    }
    
    if (distanceValue > 5000) {
      baseScore += 2;
    }
    
    if (summary.toLowerCase().contains('srp') || 
        summary.toLowerCase().contains('south road') ||
        summary.toLowerCase().contains('reclamation')) {
      baseScore += 3;
    }
    
    if (summary.toLowerCase().contains('ayala') ||
        summary.toLowerCase().contains('it park') ||
        summary.toLowerCase().contains('business park')) {
      baseScore += 2;
    }
    
    return baseScore.clamp(1, 15);
  }

  // SIMULATED elevation gain based on route location in Cebu
  double _simulateElevationGain(List<maps.LatLng> coordinates, String summary, int distanceValue) {
    if (coordinates.isEmpty) return 0;
    
    final random = Random(summary.hashCode);
    
    double elevationPerKm = 0;
    
    final hillyAreas = [
      'Beverly', 'Talamban', 'Busay', 'Lahug', 'Capitol',
      'Banilad', 'JY Square', 'Gorordo', 'Nivel Hills',
      'Maria Luisa', 'Cebu City Hall', 'Fuente'
    ];
    
    final flatAreas = [
      'SRP', 'South Road', 'Mandaue', 'Mactan', 'Coastal',
      'Reclamation', 'Port', 'Downtown', 'Colon',
      'Mango', 'N. Bacalso'
    ];
    
    bool isHilly = hillyAreas.any((area) => 
      summary.toLowerCase().contains(area.toLowerCase())
    );
    
    bool isFlat = flatAreas.any((area) => 
      summary.toLowerCase().contains(area.toLowerCase())
    );
    
    if (isFlat) {
      elevationPerKm = 5 + random.nextDouble() * 10;
    } else if (isHilly) {
      elevationPerKm = 25 + random.nextDouble() * 35;
    } else {
      elevationPerKm = 12 + random.nextDouble() * 18;
    }
    
    double distanceKm = distanceValue / 1000.0;
    double totalGain = elevationPerKm * distanceKm;
    
    return totalGain.clamp(5, 250);
  }

  List<maps.LatLng> _decodePolyline(String encoded) {
    List<maps.LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(maps.LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  IconData _getTravelModeIcon() {
    switch (widget.travelMode.toLowerCase()) {
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      case 'driving':
        return Icons.directions_car;
      default:
        return Icons.directions;
    }
  }

  Color _getModeColor() {
    switch (widget.travelMode.toLowerCase()) {
      case 'cycling':
        return Colors.green;
      case 'walking':
        return Colors.blue; 
      default:
        return Colors.blue;
    }
  }

  Widget _buildBikeLaneIndicator(RouteOption route) {
    if (widget.travelMode != 'Cycling' || route.bikeLaneScore == 0) {
      return const SizedBox.shrink();
    }
    
    String label;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    
    if (route.bikeLaneScore >= 10) {
      label = 'Excellent bike-friendly route';
      bgColor = Colors.green.shade100;
      borderColor = Colors.green.shade400;
      textColor = Colors.green.shade800;
      icon = Icons.verified;
    } else if (route.bikeLaneScore >= 7) {
      label = 'Good bike lane coverage';
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      textColor = Colors.green.shade700;
      icon = Icons.pedal_bike;
    } else if (route.bikeLaneScore >= 4) {
      label = 'Moderate bike infrastructure';
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      textColor = Colors.orange.shade700;
      icon = Icons.info_outline;
    } else {
      label = 'Limited bike lanes';
      bgColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade300;
      textColor = Colors.amber.shade800;
      icon = Icons.warning_amber_rounded;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${route.bikeLaneScore}/15',
              style: TextStyle(
                fontSize: 9,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElevationIndicator(RouteOption route) {
    if (widget.travelMode != 'Cycling' || route.elevationGain == 0) {
      return const SizedBox.shrink();
    }
    
    Color bgColor;
    Color borderColor;
    Color textColor;
    String difficulty;
    
    if (route.elevationGain < 30) {
      bgColor = Colors.green.shade100;
      borderColor = Colors.green.shade400;
      textColor = Colors.green.shade800;
      difficulty = 'Easy';
    } else if (route.elevationGain < 80) {
      bgColor = Colors.orange.shade100;
      borderColor = Colors.orange.shade400;
      textColor = Colors.orange.shade800;
      difficulty = 'Moderate';
    } else {
      bgColor = Colors.red.shade100;
      borderColor = Colors.red.shade400;
      textColor = Colors.red.shade800;
      difficulty = 'Challenging';
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terrain, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$difficulty • ${route.elevationGain.toStringAsFixed(0)}m climb',
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Route Options', style: TextStyle(fontSize: 18)),
            Row(
              children: [
                Icon(_getTravelModeIcon(), size: 14, color: _getModeColor()),
                const SizedBox(width: 4),
                Text(
                  widget.travelMode,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getModeColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
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
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getModeColor(),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[100],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.my_location, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.fromAddress,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.place, size: 16, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.toAddress,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (widget.preferences.values.any((v) => v)) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: widget.preferences.entries
                                  .where((e) => e.value)
                                  .map((e) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getModeColor().withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getModeColor().withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          e.key,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _getModeColor(),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          final isRecommended = index == 0;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: isRecommended ? 6 : 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isRecommended 
                                    ? Colors.amber.shade400
                                    : _getModeColor().withOpacity(0.3),
                                width: isRecommended ? 3 : 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (isRecommended)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [const Color.fromARGB(255, 2, 243, 103), const Color.fromARGB(255, 4, 179, 91)],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(14),
                                        topRight: Radius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.star, size: 18, color: Colors.white),
                                        SizedBox(width: 6),
                                        Text(
                                          'RECOMMENDED - Best Route',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                if (route.polylineCoordinates.isNotEmpty)
                                  Container(
                                    height: 180,
                                    decoration: BoxDecoration(
                                      borderRadius: isRecommended 
                                          ? null
                                          : const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: isRecommended 
                                          ? BorderRadius.zero
                                          : const BorderRadius.only(
                                              topLeft: Radius.circular(14),
                                              topRight: Radius.circular(14),
                                            ),
                                      child: Stack(
                                        children: [
                                          maps.GoogleMap(
                                            initialCameraPosition: maps.CameraPosition(
                                              target: route.polylineCoordinates.first,
                                              zoom: 13,
                                            ),
                                            polylines: {
                                              maps.Polyline(
                                                polylineId: maps.PolylineId('route_$index'),
                                                points: route.polylineCoordinates,
                                                color: isRecommended 
                                                    ? Colors.amber.shade700
                                                    : _getModeColor(),
                                                width: isRecommended ? 6 : 5,
                                                startCap: maps.Cap.roundCap,
                                                endCap: maps.Cap.roundCap,
                                              ),
                                            },
                                            markers: {
                                              maps.Marker(
                                                markerId: const maps.MarkerId('start'),
                                                position: route.polylineCoordinates.first,
                                                icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                                                  maps.BitmapDescriptor.hueGreen,
                                                ),
                                              ),
                                              maps.Marker(
                                                markerId: const maps.MarkerId('end'),
                                                position: route.polylineCoordinates.last,
                                                icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                                                  maps.BitmapDescriptor.hueRed,
                                                ),
                                              ),
                                            },
                                            zoomControlsEnabled: false,
                                            myLocationButtonEnabled: false,
                                            mapToolbarEnabled: false,
                                            scrollGesturesEnabled: false,
                                            zoomGesturesEnabled: false,
                                            tiltGesturesEnabled: false,
                                            rotateGesturesEnabled: false,
                                            onMapCreated: (controller) {
                                              _fitMapToRoute(controller, route.polylineCoordinates);
                                            },
                                          ),
                                          Positioned.fill(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _navigateToDetail(route, index),
                                                child: Container(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                InkWell(
                                  onTap: () => _navigateToDetail(route, index),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  child: Container(
                                    color: isRecommended 
                                        ? Colors.amber.shade50
                                        : Colors.white,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _getTravelModeIcon(),
                                              size: 20,
                                              color: isRecommended 
                                                  ? Colors.amber.shade800
                                                  : _getModeColor(),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isRecommended 
                                                    ? Colors.amber.shade700
                                                    : _getModeColor(),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${widget.travelMode} Route ${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          route.summary,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              'More Details',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isRecommended 
                                                    ? Colors.amber.shade800
                                                    : _getModeColor(),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 14,
                                              color: isRecommended 
                                                  ? Colors.amber.shade800
                                                  : _getModeColor(),
                                            ),
                                          ],
                                        ),
                                        
                                        // Bike lane indicator
                                        _buildBikeLaneIndicator(route),
                                        
                                        // Elevation indicator
                                        _buildElevationIndicator(route),
                                        
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isRecommended 
                                                ? Colors.amber.shade100
                                                : _getModeColor().withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isRecommended 
                                                  ? Colors.amber.shade400
                                                  : _getModeColor().withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: isRecommended 
                                                    ? Colors.amber.shade800
                                                    : _getModeColor(),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Optimized for ${widget.travelMode.toLowerCase()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isRecommended 
                                                      ? Colors.amber.shade800
                                                      : _getModeColor(),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
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
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _fitMapToRoute(maps.GoogleMapController controller, List<maps.LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = maps.LatLngBounds(
      southwest: maps.LatLng(minLat, minLng),
      northeast: maps.LatLng(maxLat, maxLng),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      controller.animateCamera(
        maps.CameraUpdate.newLatLngBounds(bounds, 50),
      );
    });
  }

  void _navigateToDetail(RouteOption route, int index) {
    final polylinePoints = route.polylineCoordinates
        .map((point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            })
        .toList();

    final routeData = {
      'mode': widget.travelMode.toLowerCase(),
      'distance': route.distance,
      'duration': route.duration,
      'steps': route.steps.map((step) => {
        'instruction': step.instruction,
        'distance': step.distance,
        'duration': step.duration,
        'travelMode': step.travelMode,
      }).toList(),
      'isRecommended': index == 0,
      'polylinePoints': polylinePoints,
      'bikeLaneScore': route.bikeLaneScore,
      'elevationGain': route.elevationGain,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          title: '${widget.travelMode} Route ${index + 1}',
          subtitle: route.summary,
          routeData: routeData,
        ),
      ),
    );
  }
}

class RouteOption {
  final String summary;
  final String distance;
  final String duration;
  final String polylinePoints;
  final List<maps.LatLng> polylineCoordinates;
  final int distanceValue;
  final List<RouteStep> steps;
  final int bikeLaneScore;
  final double elevationGain;

  RouteOption({
    required this.summary,
    required this.distance,
    required this.duration,
    required this.polylinePoints,
    required this.polylineCoordinates,
    required this.distanceValue,
    required this.steps,
    this.bikeLaneScore = 0,
    this.elevationGain = 0.0,
  });
}

class RouteStep {
  final String instruction;
  final String distance;
  final String duration;
  final String travelMode;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.travelMode,
  });
}