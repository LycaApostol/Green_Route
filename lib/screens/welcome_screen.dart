import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2ECC71),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Icon(Icons.directions_bike, size: 120, color: Colors.white),
            SizedBox(height: 20),
            Text('GREEN ROUTE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Text('Planner for Cyclists and Pedestrians', style: TextStyle(color: Colors.white70)),
            Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text('Get Started'),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
