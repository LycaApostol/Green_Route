import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'map_route_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

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

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onStart(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final route = {
        'title': widget.title,
        'subtitle': widget.subtitle,
        'meta': widget.routeData ?? {},
      };
      await _db.addRecentRoute(uid, route);
    }
    
    if (!mounted) return;
    
    // Pass route data to MapRouteScreen for live navigation
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
    if (_mapController == null || polylinePoints.isEmpty) return;

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

  @override
  Widget build(BuildContext context) {
    // Extract route data
    final mode = widget.routeData?['mode'] ?? 'walking';
    final distance = widget.routeData?['distance'] ?? '4.1 km';
    final duration = widget.routeData?['duration'] ?? '55 min';
    final steps = (widget.routeData?['steps'] as List<dynamic>?)
        ?.map((step) => step as Map<String, dynamic>)
        .toList() ?? [];
    final isRecommended = widget.routeData?['isRecommended'] ?? false;
    final polylinePoints = (widget.routeData?['polylinePoints'] as List<dynamic>?)
        ?.map((point) => {
          'latitude': point['latitude'],
          'longitude': point['longitude'],
        }).toList() ?? [];

    final primaryColor = mode == 'walking' ? Colors.blue : Colors.orange;
    final lightColor = mode == 'walking' ? Colors.blue[50] : Colors.orange[50];
    final darkColor = mode == 'walking' ? Colors.blue[700] : Colors.orange[700];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Animated App Bar
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  const SizedBox(height: 60),
                  // Route Type Header with Animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'route_icon_$mode',
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: lightColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  mode == 'walking' 
                                      ? Icons.directions_walk 
                                      : Icons.directions_bike,
                                  color: darkColor,
                                  size: 28,
                                ),
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
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
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Interactive Map
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Hero(
                        tag: 'route_map_$mode',
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
                                        icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                                          maps.BitmapDescriptor.hueGreen
                                        ),
                                      ),
                                      maps.Marker(
                                        markerId: const maps.MarkerId('end'),
                                        position: maps.LatLng(
                                          polylinePoints.last['latitude'],
                                          polylinePoints.last['longitude'],
                                        ),
                                        icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                                          maps.BitmapDescriptor.hueRed
                                        ),
                                      ),
                                    },
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                      Future.delayed(
                                        const Duration(milliseconds: 500),
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
                                          Icon(
                                            Icons.map_outlined,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Map preview',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
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
          
          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.access_time,
                            label: 'Duration',
                            value: duration,
                            color: primaryColor,
                            delay: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAnimatedStatCard(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: distance,
                            color: primaryColor,
                            delay: 100,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Green Score Card
                    _buildAnimatedStatCard(
                      icon: Icons.eco,
                      label: 'Green Score',
                      value: '85%',
                      color: Colors.green,
                      delay: 200,
                      isFullWidth: true,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Start Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        onPressed: () => _onStart(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          elevation: 4,
                          shadowColor: Colors.green.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
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
                    ),
                    
                    // Directions Section
                    if (steps.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      
                      // Directions Header
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
                                child: Icon(
                                  Icons.list_alt,
                                  color: darkColor,
                                  size: 24,
                                ),
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
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: _showDirections ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Animated Directions List
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _showDirections
                            ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  ...steps.asMap().entries.map((entry) {
                                    final stepIndex = entry.key;
                                    final step = entry.value;
                                    return _buildDirectionStep(
                                      stepIndex,
                                      step,
                                      primaryColor,
                                      lightColor,
                                      darkColor,
                                    );
                                  }).toList(),
                                ],
                              )
                            : const SizedBox.shrink(),
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

  Widget _buildAnimatedStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required int delay,
    bool isFullWidth = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Opacity(
            opacity: animValue,
            child: Container(
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (stepIndex * 50)),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: Padding(
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step number
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              darkColor!,
                              primaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                      
                      // Step details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
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
                                Icon(
                                  Icons.straighten,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
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
            ),
          ),
        );
      },
    );
  }
}