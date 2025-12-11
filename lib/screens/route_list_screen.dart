import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'route_detail_screen.dart';

const String googleApiKey = "";

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

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (widget.travelMode == 'Cycling' && 
            (data['status'] == 'ZERO_RESULTS' || data['routes'] == null || data['routes'].isEmpty)) {
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
            
            int bikeLaneScore = 0;
            if (widget.travelMode == 'Cycling') {
              bikeLaneScore = _simulateBikeLaneScore(
                polylineCoordinates, 
                route['summary'] ?? '',
                distanceValue
              );
            }
            
            double elevationGain = 0;
            if (widget.travelMode == 'Cycling') {
              elevationGain = _simulateElevationGain(
                polylineCoordinates,
                route['summary'] ?? '',
                distanceValue
              );
            }

            // Generate route segments with characteristics
            List<RouteSegment> segments = _generateRouteSegments(
              polylineCoordinates,
              route['summary'] ?? '',
              bikeLaneScore,
              elevationGain,
            );
            
            routesList.add(RouteOption(
              summary: route['summary'] ?? 'Route',
              distance: leg['distance']['text'] ?? '',
              duration: leg['duration']['text'] ?? '',
              polylinePoints: route['overview_polyline']['points'] ?? '',
              polylineCoordinates: polylineCoordinates,
              distanceValue: distanceValue,
              bikeLaneScore: bikeLaneScore,
              elevationGain: elevationGain,
              segments: segments,
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
    }
  }

  Future<void> _fetchFallbackRoutes() async {
    try {
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${widget.fromLocation.latitude},${widget.fromLocation.longitude}'
          '&destination=${widget.toLocation.latitude},${widget.toLocation.longitude}'
          '&mode=driving'
          '&alternatives=true'
          '&key=$googleApiKey';

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
            final drivingDuration = leg['duration']['value'] ?? 0;
            final cyclingDurationMins = (drivingDuration * 2.5 / 60).round();
            
            int bikeLaneScore = _simulateBikeLaneScore(
              polylineCoordinates, 
              route['summary'] ?? '',
              distanceValue
            );
            
            double elevationGain = _simulateElevationGain(
              polylineCoordinates,
              route['summary'] ?? '',
              distanceValue
            );

            List<RouteSegment> segments = _generateRouteSegments(
              polylineCoordinates,
              route['summary'] ?? '',
              bikeLaneScore,
              elevationGain,
            );
            
            routesList.add(RouteOption(
              summary: route['summary'] ?? 'Route',
              distance: leg['distance']['text'] ?? '',
              duration: '$cyclingDurationMins mins',
              polylinePoints: route['overview_polyline']['points'] ?? '',
              polylineCoordinates: polylineCoordinates,
              distanceValue: distanceValue,
              bikeLaneScore: bikeLaneScore,
              elevationGain: elevationGain,
              segments: segments,
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
    }
  }

  // Generate route segments with different characteristics
  List<RouteSegment> _generateRouteSegments(
    List<maps.LatLng> coordinates,
    String summary,
    int bikeLaneScore,
    double elevationGain,
  ) {
    if (coordinates.isEmpty) return [];

    List<RouteSegment> segments = [];
    final random = Random(summary.hashCode);
    
    // Divide route into segments (every ~10-15 points)
    int segmentSize = max(10, coordinates.length ~/ 5);
    
    for (int i = 0; i < coordinates.length - 1; i += segmentSize) {
      int endIndex = min(i + segmentSize, coordinates.length);
      List<maps.LatLng> segmentPoints = coordinates.sublist(i, endIndex);
      
      // Determine segment characteristics based on preferences
      SegmentType type = SegmentType.normal;
      Color color = Colors.green;
      
      if (widget.travelMode == 'Cycling') {
        // Check for bike lane preference
        if (widget.preferences['Prioritize bike lanes'] == true) {
          if (bikeLaneScore >= 10) {
            type = random.nextDouble() > 0.3 ? SegmentType.bikeLane : SegmentType.normal;
            color = type == SegmentType.bikeLane ? Colors.green.shade700 : Colors.green;
          } else if (bikeLaneScore >= 7) {
            type = random.nextDouble() > 0.5 ? SegmentType.bikeLane : SegmentType.normal;
            color = type == SegmentType.bikeLane ? Colors.green.shade600 : Colors.green;
          } else {
            type = random.nextDouble() > 0.7 ? SegmentType.bikeLane : SegmentType.mixed;
            color = type == SegmentType.bikeLane ? Colors.green : Colors.orange.shade600;
          }
        }
        
        // Check for hill preference
        if (widget.preferences['Avoid steep hills'] == true) {
          if (elevationGain > 80) {
            type = random.nextDouble() > 0.4 ? SegmentType.steep : type;
            color = type == SegmentType.steep ? Colors.red.shade600 : color;
          } else if (elevationGain > 40) {
            type = random.nextDouble() > 0.6 ? SegmentType.moderate : type;
            color = type == SegmentType.moderate ? Colors.orange.shade700 : color;
          }
        }

        // Check for scenic routes preference
        if (widget.preferences['Scenic routes'] == true) {
          if (random.nextDouble() > 0.6) {
            type = SegmentType.scenic;
            color = Colors.blue.shade600;
          }
        }

        // Check for green spaces preference
        if (widget.preferences['Prioritize green spaces'] == true) {
          if (random.nextDouble() > 0.5) {
            type = SegmentType.greenSpace;
            color = Colors.teal.shade600;
          }
        }
      } else if (widget.travelMode == 'Walking') {
        // Check for shade coverage
        if (widget.preferences['Shade coverage'] == true) {
          if (random.nextDouble() > 0.5) {
            type = SegmentType.shaded;
            color = Colors.green.shade700;
          }
        }

        // Check for pedestrian-friendly
        if (widget.preferences['Pedestrian-friendly paths'] == true) {
          if (random.nextDouble() > 0.4) {
            type = SegmentType.pedestrian;
            color = Colors.blue.shade600;
          }
        }

        // Check for scenic routes
        if (widget.preferences['Scenic routes'] == true) {
          if (random.nextDouble() > 0.6) {
            type = SegmentType.scenic;
            color = Colors.purple.shade600;
          }
        }
      }
      
      segments.add(RouteSegment(
        points: segmentPoints,
        type: type,
        color: color,
      ));
    }
    
    return segments;
  }

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

  String _getRouteName(int index, RouteOption route) {
    String shortName = widget.toAddress.split(',')[0].trim();
    return shortName;
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

  // Build legend for route segments
  Widget _buildRouteLegend() {
    List<Widget> legendItems = [];

    if (widget.travelMode == 'Cycling') {
      if (widget.preferences['Prioritize bike lanes'] == true) {
        legendItems.add(_legendItem(Colors.green.shade700, 'Dedicated bike lane'));
        legendItems.add(_legendItem(Colors.orange.shade600, 'Mixed traffic'));
      }
      if (widget.preferences['Avoid steep hills'] == true) {
        legendItems.add(_legendItem(Colors.green, 'Flat terrain'));
        legendItems.add(_legendItem(Colors.orange.shade700, 'Moderate incline'));
        legendItems.add(_legendItem(Colors.red.shade600, 'Steep hill'));
      }
      if (widget.preferences['Scenic routes'] == true) {
        legendItems.add(_legendItem(Colors.blue.shade600, 'Scenic area'));
      }
      if (widget.preferences['Prioritize green spaces'] == true) {
        legendItems.add(_legendItem(Colors.teal.shade600, 'Green space'));
      }
    } else if (widget.travelMode == 'Walking') {
      if (widget.preferences['Shade coverage'] == true) {
        legendItems.add(_legendItem(Colors.green.shade700, 'Shaded path'));
      }
      if (widget.preferences['Pedestrian-friendly paths'] == true) {
        legendItems.add(_legendItem(Colors.blue.shade600, 'Pedestrian zone'));
      }
      if (widget.preferences['Scenic routes'] == true) {
        legendItems.add(_legendItem(Colors.purple.shade600, 'Scenic area'));
      }
    }

    if (legendItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                'Route Legend',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: legendItems,
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade700,
          ),
        ),
      ],
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
                Icon(_getTravelModeIcon(), size: 14, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  widget.travelMode,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
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
          ? Center(child: CircularProgressIndicator(color: Colors.green))
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
                            backgroundColor: Colors.green,
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
                      color: Colors.green[50],
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
                              Icon(Icons.place, size: 16, color: Colors.green[900]),
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
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.green,
                                          ),
                                        ),
                                        child: Text(
                                          e.key,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green[900],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                          _buildRouteLegend(),
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
                          final routeName = _getRouteName(index, route);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: isRecommended ? 6 : 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isRecommended 
                                    ? Colors.green
                                    : Colors.green.withOpacity(0.3),
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
                                        colors: [Colors.green.shade400, Colors.green.shade600],
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
                                
                                if (route.segments.isNotEmpty)
                                  Container(
                                    height: 180,
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
                                            polylines: route.segments.map((segment) {
                                              return maps.Polyline(
                                                polylineId: maps.PolylineId('segment_${segment.hashCode}'),
                                                points: segment.points,
                                                color: segment.color,
                                                width: isRecommended ? 6 : 5,
                                                startCap: maps.Cap.roundCap,
                                                endCap: maps.Cap.roundCap,
                                              );
                                            }).toSet(),
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
                                                onTap: () => _navigateToDetail(route, index, routeName),
                                                child: Container(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                
                                InkWell(
                                  onTap: () => _navigateToDetail(route, index, routeName),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  child: Container(
                                    color: isRecommended 
                                        ? Colors.green.shade50
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
                                                  ? Colors.green.shade800
                                                  : Colors.green.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isRecommended 
                                                    ? Colors.green.shade700
                                                    : Colors.green,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                routeName,
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
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.route,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'via ${route.summary}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              route.distance,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              route.duration,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        _buildBikeLaneIndicator(route),
                                        _buildElevationIndicator(route),
                                        
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isRecommended 
                                                ? Colors.green.shade100
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.green,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.green.shade800,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Optimized for ${widget.travelMode.toLowerCase()}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green.shade800,
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

  void _navigateToDetail(RouteOption route, int index, String routeName) {
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
          title: routeName,
          subtitle: route.summary,
          routeData: routeData,
        ),
      ),
    );
  }
}

// Segment types for different route characteristics
enum SegmentType {
  normal,
  bikeLane,
  mixed,
  steep,
  moderate,
  scenic,
  greenSpace,
  shaded,
  pedestrian,
}

class RouteSegment {
  final List<maps.LatLng> points;
  final SegmentType type;
  final Color color;

  RouteSegment({
    required this.points,
    required this.type,
    required this.color,
  });
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
  final List<RouteSegment> segments;

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
    this.segments = const [],
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