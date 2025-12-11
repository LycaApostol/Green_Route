import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'map_route_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'dart:math';

class RouteDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic>? routeData;
  
  const RouteDetailScreen({
    super.key, 
    required this.title, 
    required this.subtitle, 
    this.routeData
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> 
    with SingleTickerProviderStateMixin {
  static final FirestoreService _db = FirestoreService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  maps.GoogleMapController? _mapController;
  bool _showDirections = false;
  int _expandedStepIndex = -1;
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;
  
  // Cache processed data to avoid reprocessing
  List<Map<String, dynamic>>? _cachedSteps;
  List<Map<String, dynamic>>? _cachedPolylinePoints;
  bool _isMapReady = false;
  
  // Dynamic metrics
  int _greenSpaceScore = 0;
  int _bikeLaneScore = 0;
  double _elevationGain = 0.0;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Calculate dynamic scores
    _calculateDynamicScores();
    
    // Process data asynchronously
    _processDataAsync();
    _checkIfFavorite();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Calculate dynamic scores based on route characteristics
  void _calculateDynamicScores() {
    final mode = widget.routeData?['mode'] ?? 'walking';
    final summary = widget.subtitle.toLowerCase();
    final polylinePoints = widget.routeData?['polylinePoints'] as List<dynamic>?;
    
    // Get scores from route data if available
    _bikeLaneScore = widget.routeData?['bikeLaneScore'] ?? 0;
    _elevationGain = (widget.routeData?['elevationGain'] ?? 0.0).toDouble();
    
    // Calculate green space score
    _greenSpaceScore = _calculateGreenSpaceScore(summary, polylinePoints, mode);
    
    // If bike lane score not provided, calculate it
    if (_bikeLaneScore == 0 && mode == 'bicycling') {
      _bikeLaneScore = _calculateBikeLaneScore(summary, polylinePoints);
    }
    
    // If elevation gain not provided, calculate it
    if (_elevationGain == 0.0) {
      _elevationGain = _calculateElevationGain(summary, polylinePoints);
    }
  }

  // Calculate green space score based on route characteristics
  int _calculateGreenSpaceScore(String summary, List<dynamic>? polylinePoints, String mode) {
    final random = Random(summary.hashCode);
    int baseScore = 50; // Default moderate score
    
    // Green areas and parks in Cebu
    final greenAreas = [
      'plaza', 'park', 'garden', 'botanical', 'mountain view',
      'tops', 'busay', 'terrace', 'lahug', 'capitol',
      'ayala center cebu', 'it park', 'lahug', 'beverly',
      'temple', 'taoist', 'crown regency', 'fuente',
      'riverside', 'mountain', 'terrace', 'maria luisa'
    ];
    
    // Areas with moderate greenery
    final moderateGreenAreas = [
      'banilad', 'guadalupe', 'talamban', 'pit-os',
      'kasambagan', 'mabolo', 'apas', 'jy square'
    ];
    
    // Urban/commercial areas with less greenery
    final urbanAreas = [
      'colon', 'downtown', 'carbon', 'port', 'pier',
      'mango', 'jones', 'osmeña', 'reclamation', 'srp',
      'mandaue', 'industrial', 'warehouse'
    ];
    
    // Check for high green space areas
    bool hasGreenSpace = greenAreas.any((area) => summary.contains(area));
    bool hasModerateGreen = moderateGreenAreas.any((area) => summary.contains(area));
    bool isUrban = urbanAreas.any((area) => summary.contains(area));
    
    if (hasGreenSpace) {
      baseScore = 75 + random.nextInt(20); // 75-95%
    } else if (hasModerateGreen) {
      baseScore = 55 + random.nextInt(20); // 55-75%
    } else if (isUrban) {
      baseScore = 25 + random.nextInt(25); // 25-50%
    } else {
      baseScore = 45 + random.nextInt(20); // 45-65%
    }
    
    // Bonus for walking/cycling modes (more likely to pass through green areas)
    if (mode == 'walking') {
      baseScore = min(95, baseScore + 10);
    } else if (mode == 'bicycling') {
      baseScore = min(95, baseScore + 5);
    }
    
    // Distance factor - longer routes might pass through more diverse areas
    if (polylinePoints != null && polylinePoints.length > 50) {
      baseScore = min(95, baseScore + 5);
    }
    
    return baseScore.clamp(15, 95);
  }

  // Calculate bike lane score
  int _calculateBikeLaneScore(String summary, List<dynamic>? polylinePoints) {
    final random = Random(summary.hashCode);
    int baseScore = 0;
    
    final majorRoads = [
      'osmena', 'osmeña', 'mandaue', 'mactan', 'gorordo', 
      'banilad', 'talamban', 'srp', 'cebu south road',
      'as fortuna', 'escario', 'general maxilom'
    ];
    
    bool usesMajorRoad = majorRoads.any((road) => summary.contains(road));
    
    if (usesMajorRoad) {
      baseScore = 8 + random.nextInt(4);
    } else {
      baseScore = 3 + random.nextInt(5);
    }
    
    if (summary.contains('srp') || summary.contains('south road')) {
      baseScore += 3;
    }
    
    return baseScore.clamp(1, 15);
  }

  // Calculate elevation gain
  double _calculateElevationGain(String summary, List<dynamic>? polylinePoints) {
    final random = Random(summary.hashCode);
    double elevationPerKm = 0;
    
    final hillyAreas = [
      'beverly', 'talamban', 'busay', 'lahug', 'capitol',
      'banilad', 'jy square', 'gorordo', 'nivel hills'
    ];
    
    final flatAreas = [
      'srp', 'south road', 'mandaue', 'mactan', 'coastal',
      'reclamation', 'port', 'downtown', 'colon'
    ];
    
    bool isHilly = hillyAreas.any((area) => summary.contains(area));
    bool isFlat = flatAreas.any((area) => summary.contains(area));
    
    if (isFlat) {
      elevationPerKm = 5 + random.nextDouble() * 10;
    } else if (isHilly) {
      elevationPerKm = 25 + random.nextDouble() * 35;
    } else {
      elevationPerKm = 12 + random.nextDouble() * 18;
    }
    
    // Estimate distance from polyline points
    double distanceKm = 2.0; // Default
    if (polylinePoints != null && polylinePoints.length > 1) {
      distanceKm = polylinePoints.length / 20.0; // Rough estimate
    }
    
    double totalGain = elevationPerKm * distanceKm;
    return totalGain.clamp(5, 250);
  }

  Future<void> _processDataAsync() async {
    await Future.microtask(() {
      final steps = (widget.routeData?['steps'] as List<dynamic>?)
          ?.map((step) => step as Map<String, dynamic>)
          .toList();
      
      final polylinePoints = (widget.routeData?['polylinePoints'] as List<dynamic>?)
          ?.map((point) => {
            'latitude': point['latitude'],
            'longitude': point['longitude'],
          }).toList();
      
      if (mounted) {
        setState(() {
          _cachedSteps = steps;
          _cachedPolylinePoints = polylinePoints;
        });
      }
    });
  }

  Future<void> _checkIfFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isCheckingFavorite = false);
      return;
    }

    try {
      final favorites = await _db.streamFavorites(uid).first;
      final isFav = favorites.any((fav) => 
        fav['title'] == widget.title && fav['subtitle'] == widget.subtitle
      );
      
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save favorites')),
      );
      return;
    }

    setState(() => _isFavorite = !_isFavorite);

    try {
      if (_isFavorite) {
        final favoriteData = {
          'title': widget.title,
          'subtitle': widget.subtitle,
          ...?widget.routeData,
        };
        await _db.addFavorite(uid, favoriteData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Added to favorites'),
                ],
              ),
              backgroundColor: Colors.pink[400],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final favorites = await _db.streamFavorites(uid).first;
        final favoriteToRemove = favorites.firstWhere(
          (fav) => fav['title'] == widget.title && fav['subtitle'] == widget.subtitle,
          orElse: () => {},
        );
        
        if (favoriteToRemove.isNotEmpty && favoriteToRemove['id'] != null) {
          await _db.removeFavorite(uid, favoriteToRemove['id']);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.favorite_border, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Removed from favorites'),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isFavorite = !_isFavorite);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _onStart(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final route = {
        'title': widget.title,
        'subtitle': widget.subtitle,
        'distance': widget.routeData?['distance'] ?? 'N/A',
        'duration': widget.routeData?['duration'] ?? 'N/A',
        'mode': widget.routeData?['mode'] ?? 'walking',
        'meta': widget.routeData ?? {},
      };
      _db.addRecentRoute(uid, route);
    }
    
    if (!mounted) return;
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => MapRouteScreen(
          routeData: widget.routeData,
          routeTitle: widget.title,
        ),
      ),
    );
  }

  void _fitMapToRoute(List<Map<String, dynamic>> polylinePoints) {
    if (_mapController == null || polylinePoints.isEmpty || !_isMapReady) return;

    double minLat = polylinePoints.first['latitude'];
    double maxLat = polylinePoints.first['latitude'];
    double minLng = polylinePoints.first['longitude'];
    double maxLng = polylinePoints.first['longitude'];

    for (var point in polylinePoints) {
      final lat = point['latitude'];
      final lng = point['longitude'];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = maps.LatLngBounds(
      southwest: maps.LatLng(minLat, minLng),
      northeast: maps.LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      maps.CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // Get color and label for green space score
  Map<String, dynamic> _getGreenSpaceInfo() {
    if (_greenSpaceScore >= 75) {
      return {
        'color': Colors.green,
        'label': 'Excellent',
        'icon': Icons.park,
        'description': 'Lots of green spaces'
      };
    } else if (_greenSpaceScore >= 55) {
      return {
        'color': Colors.lightGreen,
        'label': 'Good',
        'icon': Icons.nature,
        'description': 'Moderate greenery'
      };
    } else if (_greenSpaceScore >= 35) {
      return {
        'color': Colors.orange,
        'label': 'Fair',
        'icon': Icons.eco,
        'description': 'Some green areas'
      };
    } else {
      return {
        'color': Colors.grey,
        'label': 'Limited',
        'icon': Icons.location_city,
        'description': 'Urban environment'
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.routeData?['mode'] ?? 'walking';
    final distance = widget.routeData?['distance'] ?? '4.1 km';
    final duration = widget.routeData?['duration'] ?? '55 min';
    final isRecommended = widget.routeData?['isRecommended'] ?? false;
    
    final steps = _cachedSteps ?? [];
    final polylinePoints = _cachedPolylinePoints ?? [];
    
    final greenSpaceInfo = _getGreenSpaceInfo();

    final primaryColor = Colors.green;
    final lightColor = Colors.green[50]!;
    final darkColor = Colors.green[900]!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              _isCheckingFavorite
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(_isFavorite),
                          color: _isFavorite ? Colors.green[900] : Colors.grey[700],
                          size: 26,
                        ),
                      ),
                      onPressed: _toggleFavorite,
                      tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  const SizedBox(height: 60),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: lightColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                mode == 'walking' 
                                    ? Icons.directions_walk 
                                    : Icons.directions_bike,
                                color: darkColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: darkColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subtitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isRecommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.amber[600]!, Colors.amber[400]!],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Best',
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
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: polylinePoints.isNotEmpty
                              ? maps.GoogleMap(
                                  initialCameraPosition: maps.CameraPosition(
                                    target: maps.LatLng(
                                      polylinePoints.first['latitude'],
                                      polylinePoints.first['longitude'],
                                    ),
                                    zoom: 13,
                                  ),
                                  polylines: {
                                    maps.Polyline(
                                      polylineId: const maps.PolylineId('route'),
                                      points: polylinePoints
                                          .map((p) => maps.LatLng(
                                            p['latitude'], 
                                            p['longitude']
                                          ))
                                          .toList(),
                                      color: primaryColor,
                                      width: 6,
                                      startCap: maps.Cap.roundCap,
                                      endCap: maps.Cap.roundCap,
                                    ),
                                  },
                                  markers: {
                                    maps.Marker(
                                      markerId: const maps.MarkerId('start'),
                                      position: maps.LatLng(
                                        polylinePoints.first['latitude'],
                                        polylinePoints.first['longitude'],
                                      ),
                                      icon: maps.BitmapDescriptor.defaultMarkerWithHue(120.0),
                                    ),
                                    maps.Marker(
                                      markerId: const maps.MarkerId('end'),
                                      position: maps.LatLng(
                                        polylinePoints.last['latitude'],
                                        polylinePoints.last['longitude'],
                                      ),
                                      icon: maps.BitmapDescriptor.defaultMarkerWithHue(0.0),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                  liteModeEnabled: true,
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                    _isMapReady = true;
                                    Future.delayed(
                                      const Duration(milliseconds: 300),
                                      () => _fitMapToRoute(polylinePoints),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Map preview',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.access_time,
                            label: 'Duration',
                            value: duration,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: distance,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Dynamic Green Space Score
                    _buildStatCard(
                      icon: greenSpaceInfo['icon'],
                      label: 'Green Space',
                      value: '$_greenSpaceScore%',
                      color: greenSpaceInfo['color'],
                      subtitle: greenSpaceInfo['description'],
                    ),
                    
                    // Show bike lane score for cycling
                    if (mode == 'bicycling' && _bikeLaneScore > 0) ...[
                      const SizedBox(height: 12),
                      _buildStatCard(
                        icon: Icons.pedal_bike,
                        label: 'Bike-Friendly',
                        value: '$_bikeLaneScore/15',
                        color: _bikeLaneScore >= 10 
                            ? Colors.green 
                            : _bikeLaneScore >= 7 
                                ? Colors.lightGreen 
                                : Colors.orange,
                        subtitle: _bikeLaneScore >= 10 
                            ? 'Excellent bike lanes'
                            : _bikeLaneScore >= 7 
                                ? 'Good infrastructure'
                                : 'Moderate coverage',
                      ),
                    ],
                    
                    // Show elevation for cycling
                    if (mode == 'bicycling' && _elevationGain > 0) ...[
                      const SizedBox(height: 12),
                      _buildStatCard(
                        icon: Icons.terrain,
                        label: 'Elevation Gain',
                        value: '${_elevationGain.toStringAsFixed(0)}m',
                        color: _elevationGain < 30 
                            ? Colors.green 
                            : _elevationGain < 80 
                                ? Colors.orange 
                                : Colors.red,
                        subtitle: _elevationGain < 30 
                            ? 'Easy terrain'
                            : _elevationGain < 80 
                                ? 'Moderate hills'
                                : 'Challenging climbs',
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: () => _onStart(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Start Navigation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (steps.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showDirections = !_showDirections;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: lightColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.list_alt, color: darkColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Turn-by-Turn Directions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${steps.length} steps',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: _showDirections ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_showDirections)
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            ...steps.asMap().entries.map((entry) {
                              return _buildDirectionStep(
                                entry.key,
                                entry.value,
                                primaryColor,
                                lightColor,
                                darkColor,
                              );
                            }).toList(),
                          ],
                        ),
                    ],
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
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
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionStep(
    int stepIndex,
    Map<String, dynamic> step,
    Color primaryColor,
    Color? lightColor,
    Color? darkColor,
  ) {
    final stepDuration = step['duration'] ?? 'N/A';
    final stepDistance = step['distance'] ?? 'N/A';
    final instruction = step['instruction'] ?? 'Continue';
    final isExpanded = _expandedStepIndex == stepIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedStepIndex = isExpanded ? -1 : stepIndex;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isExpanded ? lightColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpanded 
                  ? primaryColor.withOpacity(0.3)
                  : Colors.grey[200]!,
              width: isExpanded ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: darkColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${stepIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          stepDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          stepDistance,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      instruction,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: isExpanded 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}