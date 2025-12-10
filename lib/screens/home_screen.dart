import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/mini_route_card.dart';
import '../services/firestore_service.dart';
import 'search_screen.dart';
import 'recent_routes_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService _db = FirestoreService();

  String selectedMode = 'Cycling'; // Default mode

  // Mode-specific preferences (single source of truth)
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

  void _navigateToSearch() {
    // Navigate to search screen with current mode and preferences
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          selectedMode: selectedMode,
          preferences: Map<String, bool>.from(modePreferences[selectedMode] ?? {}),
          onPreferencesChanged: (updatedPreferences) {
            // Update preferences when user changes them in SearchScreen
            setState(() {
              modePreferences[selectedMode] = updatedPreferences;
            });
          },
          onModeChanged: (newMode) {
            // Update mode when user changes it in SearchScreen
            setState(() {
              selectedMode = newMode;
            });
          },
        ),
      ),
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        final now = DateTime.now();
        final diff = now.difference(dt);

        if (diff.inMinutes < 1) {
          return 'Just now';
        } else if (diff.inMinutes < 60) {
          return '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          return '${diff.inHours}h ago';
        } else if (diff.inDays == 1) {
          return 'Yesterday';
        } else if (diff.inDays < 7) {
          return '${diff.inDays}d ago';
        } else {
          return DateFormat('MMM d').format(dt);
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // Extract mode from route title or metadata
  String _getRouteMode(Map<String, dynamic> route) {
    // Check if there's a mode field in the route data
    if (route['mode'] != null) {
      final mode = route['mode'].toString().toLowerCase();
      if (mode.contains('cycling') || mode.contains('bicycling')) {
        return 'Cycling';
      } else if (mode.contains('walking')) {
        return 'Walking';
      }
    }
    
    // Check meta field
    if (route['meta'] != null && route['meta'] is Map) {
      final meta = route['meta'] as Map;
      if (meta['mode'] != null) {
        final mode = meta['mode'].toString().toLowerCase();
        if (mode.contains('cycling') || mode.contains('bicycling')) {
          return 'Cycling';
        } else if (mode.contains('walking')) {
          return 'Walking';
        }
      }
    }
    
    // Fallback: Check route title
    final title = route['title']?.toString().toLowerCase() ?? '';
    if (title.contains('cycling') || title.contains('bike')) {
      return 'Cycling';
    } else if (title.contains('walking') || title.contains('walk')) {
      return 'Walking';
    }
    
    // Default fallback
    return 'Cycling';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'RouteBuddy';
    final currentPreferences = modePreferences[selectedMode] ?? {};
    final uid = user?.uid;

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
                  'Hello, $displayName 🌱',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 🔹 Search bar with tap navigation
                GestureDetector(
                  onTap: _navigateToSearch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Text(
                          'Search for routes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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

                // 🔹 Recent Activity (filtered by selected mode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (uid != null)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecentRoutesScreen(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // StreamBuilder for real-time route data (FILTERED by selectedMode)
                uid == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            children: [
                              Icon(Icons.route_outlined, 
                                size: 48, 
                                color: Colors.grey[400]
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Please login to track your routes',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _db.streamRecentRoutes(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: CircularProgressIndicator(
                                  color: Colors.green,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  'Error loading routes',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }

                          final allRoutes = snapshot.data ?? [];
                          
                          // Filter routes by selected mode
                          final filteredRoutes = allRoutes.where((route) {
                            final routeMode = _getRouteMode(route);
                            return routeMode == selectedMode;
                          }).toList();

                          if (filteredRoutes.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      selectedMode == 'Cycling' 
                                        ? Icons.directions_bike_outlined
                                        : Icons.directions_walk_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No $selectedMode routes yet 🌱',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start your first $selectedMode route to see it here!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Show only the 3 most recent routes for selected mode
                          final displayRoutes = filteredRoutes.take(3).toList();

                          return Column(
                            children: displayRoutes.map((route) {
                              // Extract actual data from route
                              final title = route['title'] ?? 'Unknown Route';
                              
                              // Get distance and duration from route or meta
                              String distance = route['distance'] ?? '';
                              String duration = route['duration'] ?? '';
                              
                              // If not in top level, check meta
                              if (distance.isEmpty && route['meta'] != null) {
                                final meta = route['meta'] as Map?;
                                distance = meta?['distance']?.toString() ?? '';
                                duration = meta?['duration']?.toString() ?? '';
                              }
                              
                              // Fallback values
                              if (distance.isEmpty) distance = '0 km';
                              if (duration.isEmpty) duration = '0 min';
                              
                              final timestamp = route['createdAt'];
                              final timeAgo = _formatTimeAgo(timestamp);
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: _buildActivityCard(
                                  title: title,
                                  distance: distance,
                                  duration: duration,
                                  timeAgo: timeAgo,
                                ),
                              );
                            }).toList(),
                          );
                        },
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

  // Custom activity card that doesn't use hardcoded data
Widget _buildActivityCard({
    required String title,
    required String distance,
    required String duration,
    required String timeAgo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeAgo.isNotEmpty ? timeAgo : 'Recently',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Distance and Duration with labels
          Row(
            children: [
              // Distance
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Distance',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          distance,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Duration
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          duration,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
              content: Text('$label mode selected - showing $label routes'),
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