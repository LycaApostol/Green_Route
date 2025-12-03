import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'route_list_screen.dart';

const String googleApiKey = "";

class SearchScreen extends StatefulWidget {
  final String? selectedMode;
  final Map<String, bool>? preferences;

  const SearchScreen({
    super.key,
    this.selectedMode,
    this.preferences,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  maps.LatLng? currentLocation;
  String? currentAddress;
  bool loading = true;

  maps.LatLng? selectedFromLocation;
  maps.LatLng? selectedToLocation;

  List<PlaceSuggestion> fromPredictions = [];
  List<PlaceSuggestion> toPredictions = [];
  
  bool showFromSuggestions = false;
  bool showToSuggestions = false;
  bool isSearchingFrom = false;
  bool isSearchingTo = false;

  // Use the passed mode or default to Cycling
  late String currentMode;
  late Map<String, bool> currentPreferences;

  // Mode-specific preferences
  final Map<String, Map<String, bool>> modePreferences = {
    'Cycling': {
      'Prioritize bike lanes': true,
      'Avoid steep hills': false,
      'Scenic routes': true,
      'Prioritize green spaces': true,
    },
    'Walking': {
      'Pedestrian-friendly paths': true,
      'Shade coverage': false,
      'Scenic routes': true,
      'Avoid highways': true,
    },
  };

  @override
  void initState() {
    super.initState();
    currentMode = widget.selectedMode ?? 'Cycling';
    currentPreferences = widget.preferences ?? modePreferences[currentMode] ?? {};
    _getCurrentLocation();
  }

  void _switchMode(String newMode) {
    setState(() {
      currentMode = newMode;
      currentPreferences = modePreferences[newMode] ?? {};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to $newMode mode'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        setState(() => loading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      // Get address from coordinates
      final address = await _getAddressFromCoordinates(pos.latitude, pos.longitude);
      
      setState(() {
        currentLocation = maps.LatLng(pos.latitude, pos.longitude);
        currentAddress = address ?? "Current Location";
        fromController.text = currentAddress!;
        selectedFromLocation = currentLocation;
        loading = false;
      });
    } catch (e) {
      print('Error getting location: $e');
      setState(() => loading = false);
    }
  }

  Future<String?> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?'
          'latlng=$lat,$lng'
          '&key=$googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  Future<void> _searchPlaces(String query, bool isFromField) async {
    if (query.isEmpty) {
      setState(() {
        if (isFromField) {
          fromPredictions = [];
          isSearchingFrom = false;
        } else {
          toPredictions = [];
          isSearchingTo = false;
        }
      });
      return;
    }

    setState(() {
      if (isFromField) {
        isSearchingFrom = true;
      } else {
        isSearchingTo = true;
      }
    });

    try {
      String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
          'input=${Uri.encodeComponent(query)}'
          '&key=$googleApiKey'
          '&components=country:ph';
      
      if (currentLocation != null) {
        url += '&location=${currentLocation!.latitude},${currentLocation!.longitude}'
               '&radius=50000';
      }

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((p) => PlaceSuggestion.fromJson(p))
              .toList();

          setState(() {
            if (isFromField) {
              fromPredictions = predictions;
              isSearchingFrom = false;
            } else {
              toPredictions = predictions;
              isSearchingTo = false;
            }
          });
        } else {
          setState(() {
            if (isFromField) {
              fromPredictions = [];
              isSearchingFrom = false;
            } else {
              toPredictions = [];
              isSearchingTo = false;
            }
          });
        }
      }
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        if (isFromField) {
          isSearchingFrom = false;
        } else {
          isSearchingTo = false;
        }
      });
    }
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion, bool isFromField) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json?'
          'place_id=${suggestion.placeId}'
          '&fields=geometry'
          '&key=$googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final latLng = maps.LatLng(location['lat'], location['lng']);

          setState(() {
            if (isFromField) {
              fromController.text = suggestion.description;
              selectedFromLocation = latLng;
              showFromSuggestions = false;
              fromPredictions = [];
            } else {
              toController.text = suggestion.description;
              selectedToLocation = latLng;
              showToSuggestions = false;
              toPredictions = [];
            }
          });
        }
      }
    } catch (e) {
      print('Error selecting place: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _useCurrentLocation() {
    setState(() {
      fromController.text = currentAddress ?? 'Current location';
      selectedFromLocation = currentLocation;
      showFromSuggestions = false;
      fromPredictions = [];
    });
  }

  void _searchRoutes() {
    if (selectedFromLocation == null || selectedToLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both locations from the suggestions')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteListScreen(
          fromLocation: selectedFromLocation!,
          toLocation: selectedToLocation!,
          fromAddress: fromController.text,
          toAddress: toController.text,
          travelMode: currentMode,
          preferences: currentPreferences,
        ),
      ),
    );
  }

  Widget _buildSuggestionsList({
    required List<PlaceSuggestion> predictions,
    required bool isSearching,
    required bool isFromField,
    required String currentText,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: isSearching
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          : predictions.isEmpty && currentText.isNotEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No results found. Try a different search.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    if (isFromField && currentLocation != null)
                      ListTile(
                        leading: const Icon(Icons.my_location, color: Colors.green),
                        title: const Text('Use current location'),
                        subtitle: Text(currentAddress ?? ''),
                        onTap: _useCurrentLocation,
                      ),
                    if (isFromField && currentLocation != null && predictions.isNotEmpty)
                      const Divider(height: 1),
                    ...predictions.map((p) => ListTile(
                          leading: const Icon(Icons.place, color: Colors.grey),
                          title: Text(
                            p.mainText,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            p.secondaryText,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          onTap: () => _selectPlace(p, isFromField),
                        )),
                  ],
                ),
    );
  }

  IconData _getModeIcon() {
    return currentMode == 'Cycling' 
        ? Icons.directions_bike 
        : Icons.directions_walk;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showFromSuggestions = false;
          showToSuggestions = false;
        });
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Find Route"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.green,
          elevation: 0,
          actions: [
            // Mode selector button
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<String>(
                onSelected: _switchMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getModeIcon(), size: 18, color: Colors.green[900]),
                      const SizedBox(width: 6),
                      Text(
                        currentMode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Colors.green[900], size: 20),
                    ],
                  ),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'Cycling',
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_bike,
                          color: currentMode == 'Cycling' ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Cycling',
                          style: TextStyle(
                            fontWeight: currentMode == 'Cycling' 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: currentMode == 'Cycling' ? Colors.green : Colors.black,
                          ),
                        ),
                        if (currentMode == 'Cycling') ...[
                          const Spacer(),
                          const Icon(Icons.check, color: Colors.green, size: 20),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'Walking',
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_walk,
                          color: currentMode == 'Walking' ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Walking',
                          style: TextStyle(
                            fontWeight: currentMode == 'Walking' 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: currentMode == 'Walking' ? Colors.blue : Colors.black,
                          ),
                        ),
                        if (currentMode == 'Walking') ...[
                          const Spacer(),
                          const Icon(Icons.check, color: Colors.blue, size: 20),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show active preferences
                      if (currentPreferences.isNotEmpty && currentPreferences.values.any((v) => v))
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active Preferences',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: currentPreferences.entries
                                    .where((e) => e.value)
                                    .map((e) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Text(
                                            e.key,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[800],
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                      TextField(
                        controller: fromController,
                        onTap: () {
                          setState(() {
                            showFromSuggestions = true;
                            showToSuggestions = false;
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            showFromSuggestions = true;
                            selectedFromLocation = null;
                          });
                          _searchPlaces(value, true);
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.my_location, color: Colors.green),
                          labelText: "Starting from",
                          hintText: "Enter starting point",
                          filled: true,
                          fillColor: Colors.green[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: fromController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      fromController.clear();
                                      selectedFromLocation = null;
                                      fromPredictions = [];
                                      showFromSuggestions = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                      
                      if (showFromSuggestions)
                        _buildSuggestionsList(
                          predictions: fromPredictions,
                          isSearching: isSearchingFrom,
                          isFromField: true,
                          currentText: fromController.text,
                        ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: toController,
                        onTap: () {
                          setState(() {
                            showToSuggestions = true;
                            showFromSuggestions = false;
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            showToSuggestions = true;
                            selectedToLocation = null;
                          });
                          _searchPlaces(value, false);
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.place, color: Colors.red),
                          labelText: "Where to?",
                          hintText: "Enter destination",
                          filled: true,
                          fillColor: Colors.red[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: toController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      toController.clear();
                                      selectedToLocation = null;
                                      toPredictions = [];
                                      showToSuggestions = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),

                      if (showToSuggestions)
                        _buildSuggestionsList(
                          predictions: toPredictions,
                          isSearching: isSearchingTo,
                          isFromField: false,
                          currentText: toController.text,
                        ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _searchRoutes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getModeIcon(), color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Search $currentMode Routes',
                              style: const TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? json['description'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
    );
  }
}