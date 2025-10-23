import 'package:flutter/material.dart';
import 'route_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Automatically fill 'From' with "Current Location"
    _fromCtrl.text = "Current Location";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Route'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              // 🔹 From field (read-only with "Current Location")
              TextField(
                controller: _fromCtrl,
                readOnly: true, // prevent typing
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.my_location),
                  filled: true,
                  fillColor: Colors.green[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 🔹 To field (editable)
              TextField(
                controller: _toCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.place),
                  hintText: 'To',
                  filled: true,
                  fillColor: Colors.green[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🔹 Search button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RouteListScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
