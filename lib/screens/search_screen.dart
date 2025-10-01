import 'package:flutter/material.dart';
import 'route_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fromCtrl = TextEditingController(text: 'Current Location');
  final _toCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Route'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(children: [
            TextField(controller: _fromCtrl, decoration: InputDecoration(prefixIcon: Icon(Icons.my_location), filled: true, fillColor: Colors.green[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            TextField(controller: _toCtrl, decoration: InputDecoration(prefixIcon: Icon(Icons.place), hintText: 'To', filled: true, fillColor: Colors.green[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // simulate search results
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteListScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size.fromHeight(48)),
              child: const Text('Search'),
            ),
          ]),
        ),
      ),
    );
  }
}
