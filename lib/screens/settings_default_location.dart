import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDefaultLocationScreen extends StatefulWidget {
  const SettingsDefaultLocationScreen({super.key});

  @override
  State<SettingsDefaultLocationScreen> createState() => _SettingsDefaultLocationScreenState();
}

class _SettingsDefaultLocationScreenState extends State<SettingsDefaultLocationScreen> {
  bool _useCurrentLocation = true;
  bool _locationAccuracy = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useCurrentLocation = prefs.getBool('use_current_location') ?? true;
      _locationAccuracy = prefs.getBool('location_accuracy') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveUseCurrentLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_current_location', value);
    
    setState(() {
      _useCurrentLocation = value;
    });

    if (value) {
      // Check location permission when enabling
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
      }
    }
  }

  Future<void> _saveLocationAccuracy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_accuracy', value);
    
    setState(() {
      _locationAccuracy = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value 
            ? 'Location accuracy enabled for better results'
            : 'Location accuracy disabled to save battery',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'To use your current location automatically, please enable location permissions in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.requestPermission();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Default Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // LOCATION SERVICES Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'LOCATION SERVICES',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // Use Current Location
          Container(
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: const Text(
                'Use Current Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Allow app to detect your location automatically',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              trailing: Switch(
                value: _useCurrentLocation,
                onChanged: _saveUseCurrentLocation,
                activeColor: Colors.green,
              ),
            ),
          ),

          const Divider(height: 1, indent: 16),

          // Location Accuracy
          Container(
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: const Text(
                'Location Accuracy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Precise location for better results',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              trailing: Switch(
                value: _locationAccuracy,
                onChanged: _saveLocationAccuracy,
                activeColor: Colors.green,
              ),
            ),
          ),

          const Divider(height: 1, indent: 16),

          // Information card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _useCurrentLocation
                        ? 'Your location will be automatically detected when you open the app. You can always manually enter a location in the search.'
                        : 'You will need to manually enter your location each time you search for routes.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Additional settings (optional)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'ABOUT LOCATION',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(Icons.location_on_outlined, color: Colors.grey[700]),
            title: const Text('Location Permission'),
            subtitle: Text(
              'Manage app location access',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: () async {
              // Open device location settings
              final permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                await Geolocator.requestPermission();
              } else if (permission == LocationPermission.deniedForever) {
                await Geolocator.openLocationSettings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location permission is already granted'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}