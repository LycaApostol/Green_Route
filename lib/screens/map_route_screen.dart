import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapRouteScreen extends StatefulWidget {
  const MapRouteScreen({super.key});
  @override
  State<MapRouteScreen> createState() => _MapRouteScreenState();
}

class _MapRouteScreenState extends State<MapRouteScreen> {
  GoogleMapController? _controller;
  LatLng? _current;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _current = LatLng(pos.latitude, pos.longitude));
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(_current!, 15));
    } catch (e) {
      // ignore for demo
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _current == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              GoogleMap(initialCameraPosition: CameraPosition(target: _current!, zoom: 14), myLocationEnabled: true, onMapCreated: (c) => _controller = c),
              Positioned(
                left: 12,
                right: 12,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [Icon(Icons.directions_walk), const SizedBox(width: 8), Expanded(child: Text('Walk — Osmeña Blvd')), IconButton(onPressed: (){}, icon: Icon(Icons.share))]),
                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: ElevatedButton(onPressed: (){}, child: Text('Start')))]),
                  ]),
                ),
              )
            ]),
    );
  }
}
