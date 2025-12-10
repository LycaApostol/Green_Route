import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  StreamSubscription<CompassEvent>? _compassStream;

  // Notification plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Navigation state
  bool _isNavigating = false;
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0;
  double _totalDistanceRemaining = 0;
  String _estimatedTimeRemaining = '';
  bool _hasReachedDestination = false;
  double _currentBearing = 0.0;
  double _currentSpeed = 0.0;

  // Route data
  List<LatLng> _routePoints = [];
  List<LatLng> _originalRoutePoints = [];
  List<Map<String, dynamic>> _steps = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _endIcon;
  BitmapDescriptor? _userLocationIcon;

  // Traveled path tracking
  List<LatLng> _traveledPath = [];
  
  // Notification settings
  bool _allowNotifications = true;
  bool _arrivalNotifications = true;

  // UI state
  bool _isFollowingUser = true;
  double _currentZoom = 19.0; // Changed default for navigation

  // Enhanced tracking
  int _closestPointIndex = 0;
  bool _hasShownArrivalNotification = false;

  // Enhanced green palette
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color darkGreen = Color(0xFF059669);
  static const Color lightGreen = Color(0xFFD1FAE5);
  static const Color accentGreen = Color(0xFF34D399);

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadNotificationSettings();
    _loadCustomMarkers();
    _loadRouteData();
    _determinePosition();
    _startCompass();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowNotifications = prefs.getBool('allow_notifications') ?? true;
      _arrivalNotifications = prefs.getBool('arrival_notifications') ?? true;
    });
  }

  Future<void> _showArrivalNotification() async {
    if (!_allowNotifications || !_arrivalNotifications || _hasShownArrivalNotification) return;

    _hasShownArrivalNotification = true;

    const androidDetails = AndroidNotificationDetails(
      'navigation_channel',
      'Navigation',
      channelDescription: 'Navigation arrival notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0,
      'Destination Reached! 🎉',
      'You have arrived at ${widget.routeTitle ?? "your destination"}',
      notificationDetails,
    );
  }

  void _startCompass() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        if (_currentSpeed < 1.5) {
          setState(() {
            _currentBearing = event.heading!;
          });
          
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

    await _createUserLocationIcon();
  }

  Future<void> _createUserLocationIcon() async {
    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final size = 80.0;

      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        outerPaint,
      );

      final innerPaint = Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        (size / 2) - 5,
        innerPaint,
      );

      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        8,
        centerPaint,
      );

      final arrowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      final arrowPath = Path();
      arrowPath.moveTo(size / 2, 10);
      arrowPath.lineTo(size / 2 - 8, 26);
      arrowPath.lineTo(size / 2, 22);
      arrowPath.lineTo(size / 2 + 8, 26);
      arrowPath.close();
      canvas.drawPath(arrowPath, arrowPaint);

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final uint8List = byteData.buffer.asUint8List();
        _userLocationIcon = BitmapDescriptor.fromBytes(uint8List);
      }
    } catch (e) {
      print('Error creating custom icon: $e');
      _userLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  void _loadRouteData() {
    if (widget.routeData == null) return;

    final polylinePoints = widget.routeData?['polylinePoints'] as List<dynamic>?;
    if (polylinePoints != null) {
      _routePoints = polylinePoints
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();
      _originalRoutePoints = List.from(_routePoints);
    }

    final steps = widget.routeData?['steps'] as List<dynamic>?;
    if (steps != null) {
      _steps = steps.map((s) => s as Map<String, dynamic>).toList();
    }

    _updatePolylines();

    if (_routePoints.isNotEmpty) {
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

  void _updatePolylines() {
    _polylines.clear();
    
    // Add traveled path (gray)
    if (_traveledPath.length > 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('traveled'),
          points: _traveledPath,
          color: Colors.grey[400]!,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    // Add remaining route (green) - shows actual remaining path
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
    }
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

    // Initialize traveled path with current position
    _traveledPath.clear();
    _traveledPath.add(_current!);

    // Find the closest point on route to start from
    _findClosestPointOnRoute(_current!);

    // Animate camera with smooth zoom and tilt like Waze/Google Maps
    _animateNavigationStart();

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
      _hasShownArrivalNotification = false;
    });

    _showNotification('Navigation started', Icons.navigation, primaryGreen);
  }

  Future<void> _animateNavigationStart() async {
    if (_controller == null || _current == null) return;

    // Step 1: Zoom out to show full route (like Google Maps overview)
    if (_originalRoutePoints.isNotEmpty) {
      // Calculate bounds of the route
      double minLat = _originalRoutePoints.first.latitude;
      double maxLat = _originalRoutePoints.first.latitude;
      double minLng = _originalRoutePoints.first.longitude;
      double maxLng = _originalRoutePoints.first.longitude;

      for (var point in _originalRoutePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Animate to show full route
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );

      // Wait a moment to show the full route
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    // Step 2: Zoom into navigation view (like Waze entering navigation mode)
    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _current!,
          zoom: 18.5, // Closer zoom for navigation
          bearing: _currentBearing,
          tilt: 55, // More tilted for 3D effect
        ),
      ),
    );

    // Step 3: Settle into final navigation view
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted && _controller != null && _current != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _current!,
            zoom: 19, // Final navigation zoom
            bearing: _currentBearing,
            tilt: 60, // Navigation tilt
          ),
        ),
      );
    }
  }

  void _findClosestPointOnRoute(LatLng currentLocation) {
    if (_originalRoutePoints.isEmpty) return;

    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _originalRoutePoints.length; i++) {
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        _originalRoutePoints[i].latitude,
        _originalRoutePoints[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    _closestPointIndex = closestIndex;
    
    // Update route points to start from closest point
    if (closestIndex < _originalRoutePoints.length) {
      _routePoints = _originalRoutePoints.sublist(closestIndex);
    }
  }

  void _onLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    
    setState(() {
      _current = newLocation;
      _currentSpeed = position.speed;
      
      if (position.speed > 1.5) {
        _currentBearing = position.heading;
      }

      // Add to traveled path with minimum distance threshold
      if (_traveledPath.isEmpty || 
          _calculateDistance(
            _traveledPath.last.latitude,
            _traveledPath.last.longitude,
            newLocation.latitude,
            newLocation.longitude,
          ) > 5) {
        _traveledPath.add(newLocation);
      }

      // Update remaining route accurately
      if (_originalRoutePoints.isNotEmpty) {
        _updateRemainingRouteAccurate(newLocation);
      }
    });

    _updateUserMarker(position);
    _updatePolylines();

    if (_isFollowingUser && _controller != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newLocation,
            zoom: _currentZoom,
            bearing: _currentBearing,
            tilt: 60, // Navigation tilt
          ),
        ),
      );
    }

    if (_originalRoutePoints.isNotEmpty && !_hasReachedDestination) {
      _calculateNavigationProgress(position);
    }
  }

  void _updateRemainingRouteAccurate(LatLng currentLocation) {
    if (_originalRoutePoints.isEmpty) return;

    // Find the closest point on the route
    double minDistance = double.infinity;
    int closestIndex = _closestPointIndex;

    // Search in a window around the current closest point for efficiency
    int searchStart = max(0, _closestPointIndex - 5);
    int searchEnd = min(_originalRoutePoints.length, _closestPointIndex + 20);

    for (int i = searchStart; i < searchEnd; i++) {
      final distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        _originalRoutePoints[i].latitude,
        _originalRoutePoints[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Update the closest point index
    if (closestIndex > _closestPointIndex) {
      _closestPointIndex = closestIndex;
    }

    // Update route points to show remaining path accurately
    // Include current location as first point for smooth transition
    if (_closestPointIndex < _originalRoutePoints.length - 1) {
      _routePoints = [
        currentLocation,
        ..._originalRoutePoints.sublist(_closestPointIndex + 1),
      ];
    } else if (_closestPointIndex == _originalRoutePoints.length - 1) {
      // Near the end, just show line to destination
      _routePoints = [
        currentLocation,
        _originalRoutePoints.last,
      ];
    }
  }

  void _updateUserMarker(Position position) {
    _markers.removeWhere((m) => m.markerId.value == 'user_location');
    _circles.clear();
    
    _circles.add(
      Circle(
        circleId: const CircleId('accuracy_circle'),
        center: LatLng(position.latitude, position.longitude),
        radius: position.accuracy.clamp(5.0, 100.0),
        fillColor: const Color(0xFF4285F4).withOpacity(0.1),
        strokeColor: const Color(0xFF4285F4).withOpacity(0.3),
        strokeWidth: 2,
      ),
    );
    
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: _userLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        rotation: _currentBearing,
        flat: true,
        zIndex: 999,
        infoWindow: InfoWindow(
          title: 'You are here',
          snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(1)}m',
        ),
      ),
    );
    
    setState(() {});
  }

  void _calculateNavigationProgress(Position currentPos) {
    if (_steps.isEmpty) return;

    final currentLatLng = LatLng(currentPos.latitude, currentPos.longitude);
    
    // Calculate distance to destination
    final destDistance = _calculateDistance(
      currentLatLng.latitude,
      currentLatLng.longitude,
      _originalRoutePoints.last.latitude,
      _originalRoutePoints.last.longitude,
    );

    // Check if reached destination (within 20 meters)
    if (destDistance < 20 && !_hasReachedDestination) {
      _reachedDestination();
      return;
    }

    // Update step progress
    if (_closestPointIndex < _originalRoutePoints.length - 1) {
      final nextPoint = _originalRoutePoints[_closestPointIndex + 1];
      
      _distanceToNextStep = _calculateDistance(
        currentLatLng.latitude,
        currentLatLng.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );

      // Advance step if close enough (within 25 meters)
      if (_distanceToNextStep < 25 && _currentStepIndex < _steps.length - 1) {
        _advanceToNextStep();
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
    if (_hasReachedDestination) return;

    setState(() {
      _hasReachedDestination = true;
      _isNavigating = false;
    });

    _positionStream?.cancel();
    
    // Show notification
    _showArrivalNotification();

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
        content: Text('You have reached ${widget.routeTitle ?? "your destination"}! 🎉'),
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
    
    if (_current != null && _originalRoutePoints.isNotEmpty && _closestPointIndex < _originalRoutePoints.length) {
      // Distance from current location to next point
      if (_closestPointIndex + 1 < _originalRoutePoints.length) {
        totalDistance += _calculateDistance(
          _current!.latitude,
          _current!.longitude,
          _originalRoutePoints[_closestPointIndex + 1].latitude,
          _originalRoutePoints[_closestPointIndex + 1].longitude,
        );

        // Sum up remaining segments
        for (int i = _closestPointIndex + 1; i < _originalRoutePoints.length - 1; i++) {
          totalDistance += _calculateDistance(
            _originalRoutePoints[i].latitude,
            _originalRoutePoints[i].longitude,
            _originalRoutePoints[i + 1].latitude,
            _originalRoutePoints[i + 1].longitude,
          );
        }
      } else {
        // Just distance to final destination
        totalDistance = _calculateDistance(
          _current!.latitude,
          _current!.longitude,
          _originalRoutePoints.last.latitude,
          _originalRoutePoints.last.longitude,
        );
      }
    }

    _totalDistanceRemaining = totalDistance;

    // Calculate ETA based on mode
    final mode = widget.routeData?['mode'] ?? 'walking';
    final speedKmh = mode == 'walking' ? 5.0 : 15.0; // walking: 5km/h, biking: 15km/h
    final hours = (totalDistance / 1000) / speedKmh;
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
            tilt: _isNavigating ? 60 : 45,
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
                  circles: _circles,
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
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}