import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui; // ADD THIS
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

class MapRouteScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;
  final String? routeTitle;

  const MapRouteScreen({
    super.key,
    this.routeData,
    this.routeTitle,
  });

  @override
  State<MapRouteScreen> createState() => _MapRouteScreenState();
}

class _MapRouteScreenState extends State<MapRouteScreen> {
  GoogleMapController? _controller;
  LatLng? _current;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream; // ADD THIS

  // Navigation state
  bool _isNavigating = false;
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0;
  double _totalDistanceRemaining = 0;
  String _estimatedTimeRemaining = '';
  bool _hasReachedDestination = false;
  double _currentBearing = 0.0;
  double _currentSpeed = 0.0; // ADD THIS to track movement speed

  // Route data
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _steps = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {}; // ADD THIS for location circle
  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _endIcon;
  BitmapDescriptor? _userLocationIcon;

  // UI state
  bool _isFollowingUser = true;
  double _currentZoom = 17.0;

  // Enhanced green palette
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color darkGreen = Color(0xFF059669);
  static const Color lightGreen = Color(0xFFD1FAE5);
  static const Color accentGreen = Color(0xFF34D399);

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _loadRouteData();
    _determinePosition();
    _startCompass(); // ADD THIS
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel(); // ADD THIS
    _controller?.dispose();
    super.dispose();
  }

  // ADD THIS METHOD
  void _startCompass() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        // Only use compass bearing when not moving fast
        // When moving fast, GPS heading is more accurate
        if (_currentSpeed < 1.5) { // Less than 1.5 m/s (5.4 km/h)
          setState(() {
            _currentBearing = event.heading!;
          });
          
          // Update camera rotation if following user
          if (_isFollowingUser && _current != null && _controller != null) {
            _controller!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _current!,
                  zoom: _currentZoom,
                  bearing: _currentBearing,
                  tilt: _isNavigating ? 50 : 45,
                ),
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _loadCustomMarkers() async {
    _startIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/start_marker.png',
    ).catchError((_) => BitmapDescriptor.defaultMarkerWithHue(140.0));

    _endIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/end_marker.png',
    ).catchError((_) => BitmapDescriptor.defaultMarkerWithHue(0.0));
  }

  // ADD THIS METHOD - Creates custom user location icon
  Future<void> _createUserLocationIcon() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 60.0;

    // Draw outer circle (white border)
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      outerPaint,
    );

    // Draw inner circle (blue dot)
    final innerPaint = Paint()
      ..color = const Color(0xFF4285F4) // Google Maps blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      (size / 2) - 4,
      innerPaint,
    );

    // Draw direction indicator (small triangle)
    final trianglePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final trianglePath = Path();
    trianglePath.moveTo(size / 2, 8); // Top point
    trianglePath.lineTo(size / 2 - 6, 20); // Bottom left
    trianglePath.lineTo(size / 2 + 6, 20); // Bottom right
    trianglePath.close();
    canvas.drawPath(trianglePath, trianglePaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    _userLocationIcon = BitmapDescriptor.fromBytes(uint8List);
  }

  void _loadRouteData() {
    if (widget.routeData == null) return;

    final polylinePoints = widget.routeData?['polylinePoints'] as List<dynamic>?;
    if (polylinePoints != null) {
      _routePoints = polylinePoints
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();
    }

    final steps = widget.routeData?['steps'] as List<dynamic>?;
    if (steps != null) {
      _steps = steps.map((s) => s as Map<String, dynamic>).toList();
    }

    if (_routePoints.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: primaryGreen,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      if (_startIcon != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('start'),
            position: _routePoints.first,
            icon: _startIcon!,
            infoWindow: const InfoWindow(title: 'Start'),
          ),
        );
      }

      if (_endIcon != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _routePoints.last,
            icon: _endIcon!,
            infoWindow: const InfoWindow(title: 'Destination'),
          ),
        );
      }
    }

    setState(() {});
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied');
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _current = LatLng(pos.latitude, pos.longitude);
        _currentSpeed = pos.speed;
        // Only use GPS heading if moving
        if (pos.speed > 1.5) {
          _currentBearing = pos.heading;
        }
      });
      
      _updateUserMarker(pos);
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _current!,
            zoom: 17,
            bearing: _currentBearing,
            tilt: 45,
          ),
        ),
      );
    } catch (e) {
      _showError('Could not get location: $e');
    }
  }

  void _startNavigation() {
    if (_current == null) {
      _showError('Waiting for your location...');
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _onLocationUpdate(position);
    });

    setState(() {
      _isNavigating = true;
    });

    _showNotification('Navigation started', Icons.navigation, primaryGreen);
  }

  void _onLocationUpdate(Position position) {
    setState(() {
      _current = LatLng(position.latitude, position.longitude);
      _currentSpeed = position.speed; // UPDATE SPEED
      
      // Use GPS heading only when moving fast enough
      // Otherwise compass will handle rotation
      if (position.speed > 1.5) { // Moving faster than 1.5 m/s
        _currentBearing = position.heading;
      }
    });

    _updateUserMarker(position);

    if (_isFollowingUser && _controller != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: _currentZoom,
            bearing: _currentBearing,
            tilt: 50,
          ),
        ),
      );
    }

    if (_routePoints.isNotEmpty && !_hasReachedDestination) {
      _calculateNavigationProgress(position);
    }
  }

  void _updateUserMarker(Position position) {
    // Remove old marker and circle
    _markers.removeWhere((m) => m.markerId.value == 'user_location');
    _circles.clear();
    
    // Add pulsing accuracy circle
    _circles.add(
      Circle(
        circleId: const CircleId('accuracy_circle'),
        center: LatLng(position.latitude, position.longitude),
        radius: position.accuracy,
        fillColor: const Color(0xFF4285F4).withOpacity(0.1),
        strokeColor: const Color(0xFF4285F4).withOpacity(0.3),
        strokeWidth: 1,
      ),
    );
    
    // Add custom user location marker
    if (_userLocationIcon != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(position.latitude, position.longitude),
          icon: _userLocationIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: _currentBearing,
          flat: true,
          zIndex: 999,
          infoWindow: InfoWindow(
            title: 'You are here',
            snippet: '${position.accuracy.toStringAsFixed(1)}m accuracy',
          ),
        ),
      );
    }
    
    setState(() {});
  }

  void _calculateNavigationProgress(Position currentPos) {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return;

    final currentLatLng = LatLng(currentPos.latitude, currentPos.longitude);
    
    final nextStepIndex = _currentStepIndex + 1;
    if (nextStepIndex < _routePoints.length) {
      final nextPoint = _routePoints[nextStepIndex];
      
      _distanceToNextStep = _calculateDistance(
        currentLatLng.latitude,
        currentLatLng.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );

      if (_distanceToNextStep < 20 && _currentStepIndex < _steps.length - 1) {
        _advanceToNextStep();
      }

      if (_currentStepIndex == _steps.length - 1) {
        final destDistance = _calculateDistance(
          currentLatLng.latitude,
          currentLatLng.longitude,
          _routePoints.last.latitude,
          _routePoints.last.longitude,
        );

        if (destDistance < 15) {
          _reachedDestination();
        }
      }
    }

    _calculateRemainingStats();
    setState(() {});
  }

  void _advanceToNextStep() {
    _currentStepIndex++;
    
    if (_currentStepIndex < _steps.length) {
      final step = _steps[_currentStepIndex];
      final instruction = step['instruction'] ?? 'Continue';
      _showNotification(instruction, Icons.turn_right, primaryGreen);
    }

    setState(() {});
  }

  void _reachedDestination() {
    setState(() {
      _hasReachedDestination = true;
      _isNavigating = false;
    });

    _positionStream?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: primaryGreen, size: 32),
            const SizedBox(width: 12),
            const Text('Arrived!'),
          ],
        ),
        content: const Text('You have reached your destination.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _calculateRemainingStats() {
    double totalDistance = 0;
    
    if (_current != null && _routePoints.isNotEmpty) {
      if (_currentStepIndex < _routePoints.length) {
        totalDistance += _calculateDistance(
          _current!.latitude,
          _current!.longitude,
          _routePoints[_currentStepIndex].latitude,
          _routePoints[_currentStepIndex].longitude,
        );

        for (int i = _currentStepIndex; i < _routePoints.length - 1; i++) {
          totalDistance += _calculateDistance(
            _routePoints[i].latitude,
            _routePoints[i].longitude,
            _routePoints[i + 1].latitude,
            _routePoints[i + 1].longitude,
          );
        }
      }
    }

    _totalDistanceRemaining = totalDistance;

    final hours = totalDistance / 5000;
    final minutes = (hours * 60).round();
    _estimatedTimeRemaining = minutes > 60
        ? '${(minutes / 60).floor()}h ${minutes % 60}min'
        : '${minutes}min';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void _showNotification(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 200,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  void _toggleFollowUser() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;
    });

    if (_isFollowingUser && _current != null) {
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _current!,
            zoom: _currentZoom,
            bearing: _currentBearing,
            tilt: 50,
          ),
        ),
      );
    }
  }

  void _stopNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Navigation'),
        content: const Text('Are you sure you want to stop navigation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _positionStream?.cancel();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _current == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _current!,
                    zoom: 17,
                    bearing: _currentBearing,
                    tilt: 45,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  circles: _circles, // ADD THIS
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (c) => _controller = c,
                  onCameraMove: (position) {
                    _currentZoom = position.zoom;
                  },
                ),

                if (_isNavigating) ...[
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_currentStepIndex < _steps.length)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: lightGreen,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.navigation,
                                        color: darkGreen,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _steps[_currentStepIndex]['instruction'] ?? 'Continue',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_distanceToNextStep.round()}m',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    Icons.access_time,
                                    _estimatedTimeRemaining,
                                    'ETA',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                                  _buildStatItem(
                                    Icons.straighten,
                                    '${(_totalDistanceRemaining / 1000).toStringAsFixed(1)} km',
                                    'Remaining',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                                  _buildStatItem(
                                    Icons.route,
                                    '${_currentStepIndex + 1}/${_steps.length}',
                                    'Step',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: !_isNavigating
                        ? _buildStartPanel()
                        : _buildNavigatingPanel(),
                  ),
                ),

                if (_isNavigating)
                  Positioned(
                    right: 16,
                    bottom: 140,
                    child: FloatingActionButton(
                      heroTag: 'recenter',
                      onPressed: _toggleFollowUser,
                      backgroundColor: _isFollowingUser ? primaryGreen : Colors.white,
                      elevation: 4,
                      child: Icon(
                        Icons.my_location,
                        color: _isFollowingUser ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStartPanel() {
    final mode = widget.routeData?['mode'] ?? 'walking';
    final routeName = widget.routeTitle ?? 'Route';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              mode == 'walking' ? Icons.directions_walk : Icons.directions_bike,
              color: primaryGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                routeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                _showNotification('Share feature coming soon', Icons.share, primaryGreen);
              },
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _startNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.navigation, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigatingPanel() {
    return ElevatedButton.icon(
      onPressed: _stopNavigation,
      icon: const Icon(Icons.stop_circle),
      label: const Text(
        'Stop Navigation',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: primaryGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}