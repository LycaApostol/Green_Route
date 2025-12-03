import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/mini_route_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController searchController = TextEditingController();

  bool prioritizeGreen = true;
  bool safeCycling = false;
  bool scenicRoutes = true;

  // If this list is empty, it means new user — no history yet.
  List<Map<String, String>> recentActivities = [];

  String selectedMode = 'Cycling'; // Default mode

  // Mode-specific preferences
  Map<String, Map<String, bool>> modePreferences = {
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
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _navigateToSearch() {
    // Always pass the current selectedMode and preferences when navigating
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          selectedMode: selectedMode,
          preferences: Map<String, bool>.from(modePreferences[selectedMode] ?? {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'RouteBuddy';
    final currentPreferences = modePreferences[selectedMode] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Dynamic greeting
                Text(
                  'Hello, $displayName 🍃',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 🔹 Search bar with tap navigation
                GestureDetector(
                  onTap: _navigateToSearch,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for routes',
                        prefixIcon: const Icon(Icons.search, color: Colors.green),
                        filled: true,
                        fillColor: Colors.green[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 🔹 Mode selection
                Row(
                  children: [
                    _modeCard(Icons.directions_bike, 'Cycling'),
                    const SizedBox(width: 12),
                    _modeCard(Icons.directions_walk, 'Walking'),
                  ],
                ),
                const SizedBox(height: 18),

                // 🔹 Tracking Activity (dynamic)
                const Text(
                  'Tracking Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                recentActivities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text(
                            'No tracking activity yet 🌱\nStart your first route to see progress here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: recentActivities
                            .map((activity) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: miniRouteCard(
                                    title: activity['title']!,
                                    subtitle: activity['subtitle']!,
                                  ),
                                ))
                            .toList(),
                      ),

                const SizedBox(height: 18),

                // 🔹 Dynamic Preferences based on selected mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$selectedMode Preferences',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedMode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Dynamic preference switches based on mode
                ...currentPreferences.entries.map((entry) {
                  return _prefRow(
                    entry.key,
                    entry.value,
                    (v) {
                      setState(() {
                        modePreferences[selectedMode]![entry.key] = v;
                      });
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Mode selection cards with highlight for selected mode
  Widget _modeCard(IconData icon, String label) {
    final isSelected = selectedMode == label;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => selectedMode = label);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label mode selected - preferences updated'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green[200] : Colors.green[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.green : Colors.transparent,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 34,
                color: isSelected ? Colors.green[900] : Colors.green[800],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.green[900] : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prefRow(String text, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(text),
      trailing: Switch(
        value: value,
        activeThumbColor: Colors.green,
        onChanged: onChanged,
      ),
    );
  }
}