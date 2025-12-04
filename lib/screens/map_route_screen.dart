import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  // Navigation state
  bool _isNavigating = false;
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0;
  double _totalDistanceRemaining = 0;
  String _estimatedTimeRemaining = '';
  bool _hasReachedDestination = false;

  // Route data
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _steps = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // UI state
  bool _isFollowingUser = true;
  double _currentZoom = 17.0;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
    _determinePosition();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _loadRouteData() {
    if (widget.routeData == null) return;

    // Load polyline points
    final polylinePoints = widget.routeData?['polylinePoints'] as List<dynamic>?;
    if (polylinePoints != null) {
      _routePoints = polylinePoints
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();
    }

    // Load steps
    final steps = widget.routeData?['steps'] as List<dynamic>?;
    if (steps != null) {
      _steps = steps.map((s) => s as Map<String, dynamic>).toList();
    }

    // Create polyline
    if (_routePoints.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: Colors.blue,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      // Add destination marker
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _routePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
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
      setState(() => _current = LatLng(pos.latitude, pos.longitude));
      
      _updateUserMarker(pos);
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(_current!, 15));
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
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _onLocationUpdate(position);
    });

    setState(() {
      _isNavigating = true;
    });

    _showNotification('Navigation started', Icons.navigation, Colors.green);
  }

  void _onLocationUpdate(Position position) {
    setState(() {
      _current = LatLng(position.latitude, position.longitude);
    });

    _updateUserMarker(position);

    // Follow user
    if (_isFollowingUser && _controller != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: _currentZoom,
            bearing: position.heading,
            tilt: 45,
          ),
        ),
      );
    }

    // Calculate navigation progress
    if (_routePoints.isNotEmpty && !_hasReachedDestination) {
      _calculateNavigationProgress(position);
    }
  }

  void _updateUserMarker(Position position) {
    _markers.removeWhere((m) => m.markerId.value == 'user_location');
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        rotation: position.heading,
        flat: true,
      ),
    );
  }

  void _calculateNavigationProgress(Position currentPos) {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return;

    final currentLatLng = LatLng(currentPos.latitude, currentPos.longitude);
    
    // Get next step location
    final nextStepIndex = _currentStepIndex + 1;
    if (nextStepIndex < _routePoints.length) {
      final nextPoint = _routePoints[nextStepIndex];
      
      _distanceToNextStep = _calculateDistance(
        currentLatLng.latitude,
        currentLatLng.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );

      // Advance to next step if close enough (within 20 meters)
      if (_distanceToNextStep < 20 && _currentStepIndex < _steps.length - 1) {
        _advanceToNextStep();
      }

      // Check if reached destination (within 15 meters)
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
      _showNotification(instruction, Icons.turn_right, Colors.blue);
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Arrived!'),
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
      // Distance to next route point
      if (_currentStepIndex < _routePoints.length) {
        totalDistance += _calculateDistance(
          _current!.latitude,
          _current!.longitude,
          _routePoints[_currentStepIndex].latitude,
          _routePoints[_currentStepIndex].longitude,
        );

        // Add remaining segments
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

    // Estimate time (5 km/h walking speed)
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
        backgroundColor: Colors.red,
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
            tilt: 45,
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _current!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
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

                // Top Navigation Info (when navigating)
                if (_isNavigating) ...[
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Current instruction
                              if (_currentStepIndex < _steps.length)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.navigation,
                                        color: Colors.blue[700],
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _steps[_currentStepIndex]
                                                    ['instruction'] ??
                                                'Continue',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
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
                              // Stats
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
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

                // Bottom panel
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: !_isNavigating
                        ? _buildStartPanel()
                        : _buildNavigatingPanel(),
                  ),
                ),

                // Recenter button (when navigating)
                if (_isNavigating)
                  Positioned(
                    right: 16,
                    bottom: 140,
                    child: FloatingActionButton(
                      heroTag: 'recenter',
                      onPressed: _toggleFollowUser,
                      backgroundColor:
                          _isFollowingUser ? Colors.blue[700] : Colors.white,
                      child: Icon(
                        Icons.my_location,
                        color:
                            _isFollowingUser ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStartPanel() {
    final mode = widget.routeData?['mode'] ?? 'walking';
    final routeName = widget.routeTitle ?? 'Walk — Osmeña Blvd';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              mode == 'walking' ? Icons.directions_walk : Icons.directions_bike,
              color: Colors.blue[700],
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
                // Share functionality
                _showNotification('Share feature coming soon', Icons.share, Colors.blue);
              },
              icon: const Icon(Icons.share),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _startNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.bold,
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
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 20),
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