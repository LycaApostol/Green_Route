import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

const String googleApiKey = "AIzaSyDyd70QnF1eLXP00HmMM7tmY1NIk-qeJmQ"; // <-- replace with your key

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  final places.FlutterGooglePlacesSdk _places = places.FlutterGooglePlacesSdk(googleApiKey);

  maps.GoogleMapController? mapController;
  maps.LatLng? fromLatLng;
  maps.LatLng? toLatLng;
  Set<maps.Polyline> polylines = {};
  bool loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _locateDevice();
  }

  Future<void> _locateDevice() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // keep default location if denied
        setState(() => loadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        fromLatLng = maps.LatLng(pos.latitude, pos.longitude);
        loadingLocation = false;
      });
    } catch (_) {
      setState(() => loadingLocation = false);
    }
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  // Opens modal that performs autocomplete queries and lists predictions.
  Future<void> _openPlaceSearch({required bool isFrom}) async {
    final TextEditingController searchCtrl = TextEditingController();
    List<places.AutocompletePrediction> predictions = [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateDialog) {
          Future<void> doQuery(String q) async {
            if (q.trim().isEmpty) {
              setStateDialog(() => predictions = []);
              return;
            }
            final result = await _places.findAutocompletePredictions(
              q,
              countries: ['ph'],
            );
            setStateDialog(() => predictions = result.predictions);
          }

          return AlertDialog(
            title: Text(isFrom ? 'Search From' : 'Search To'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(hintText: 'Type a place or address'),
                  onChanged: (v) {
                    // debounce not implemented here (simple)
                    doQuery(v);
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: predictions.isEmpty
                      ? const Center(child: Text('No suggestions yet'))
                      : ListView.separated(
                          itemCount: predictions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = predictions[index];
                            return ListTile(
                              title: Text(p.fullText ?? p.primaryText ?? 'Unknown'),
                              subtitle: Text(p.secondaryText ?? ''),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _selectPrediction(isFrom, p);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          );
        });
      },
    );

    searchCtrl.dispose();
  }

  // Fetch place details and place marker + optionally draw route.
  Future<void> _selectPrediction(bool isFrom, places.AutocompletePrediction prediction) async {
    try {
      final details = await _places.fetchPlace(
        prediction.placeId!,
        fields: [places.PlaceField.Location, places.PlaceField.Address],
      );
      final place = details.place;
      final latLng = place?.latLng;
      if (latLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No location returned')));
        return;
      }

      final selected = maps.LatLng(latLng.lat, latLng.lng);
      final display = place?.address ?? prediction.fullText ?? prediction.primaryText ?? '';

      setState(() {
        if (isFrom) {
          fromController.text = display;
          fromLatLng = selected;
        } else {
          toController.text = display;
          toLatLng = selected;
        }
      });

      // animate camera to selected
      await mapController?.animateCamera(maps.CameraUpdate.newLatLngZoom(selected, 14));

      // if we have both start & destination, draw a straight polyline (replace later with Directions API)
      if (fromLatLng != null && toLatLng != null) {
        _drawStraightPolyline(fromLatLng!, toLatLng!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Place details error: $e')));
    }
  }

  // Draw a direct line between start and end (simple). Use Directions API for real route.
  void _drawStraightPolyline(maps.LatLng start, maps.LatLng end) {
    final id = const maps.PolylineId('route');
    final poly = maps.Polyline(
      polylineId: id,
      points: [start, end],
      color: Colors.green,
      width: 5,
    );
    setState(() {
      polylines = {poly};
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = maps.CameraPosition(
      target: fromLatLng ?? const maps.LatLng(10.3157, 123.8854), // Cebu fallback
      zoom: 12,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Route'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _buildField('From', fromController, Icons.my_location, true),
                const SizedBox(height: 10),
                _buildField('To', toController, Icons.place, false),
              ],
            ),
          ),
          Expanded(
            child: loadingLocation
                ? const Center(child: CircularProgressIndicator())
                : maps.GoogleMap(
                    initialCameraPosition: initialCamera,
                    onMapCreated: (c) => mapController = c,
                    mapType: maps.MapType.normal,
                    markers: {
                      if (fromLatLng != null)
                        maps.Marker(
                          markerId: const maps.MarkerId('from'),
                          position: fromLatLng!,
                          infoWindow: const maps.InfoWindow(title: 'From'),
                          icon: maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueGreen),
                        ),
                      if (toLatLng != null)
                        maps.Marker(
                          markerId: const maps.MarkerId('to'),
                          position: toLatLng!,
                          infoWindow: const maps.InfoWindow(title: 'To'),
                          icon: maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueRed),
                        ),
                    },
                    polylines: polylines,
                    myLocationEnabled: true,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isFrom) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      onTap: () => _openPlaceSearch(isFrom: isFrom),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.green),
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}