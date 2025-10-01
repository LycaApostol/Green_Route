import 'package:flutter/material.dart';
import 'settings_default_location.dart';
import 'settings_notifications.dart';
import 'settings_privacy.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(children: [
            Row(children: [
              CircleAvatar(radius: 36, backgroundImage: AssetImage('assets/avatar_placeholder.png')), // add asset
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Kinemberlo', style: TextStyle(fontWeight: FontWeight.bold)), Text('View/edit profile')])
            ]),
            const SizedBox(height: 18),
            ListTile(title: Text('Default Location'), trailing: Icon(Icons.chevron_right), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultLocationSettings()))),
            ListTile(title: Text('Notifications'), trailing: Icon(Icons.chevron_right), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettings()))),
            ListTile(title: Text('Privacy & Security'), trailing: Icon(Icons.chevron_right), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettings()))),
            const Spacer(),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400], minimumSize: const Size.fromHeight(48)), onPressed: (){}, child: const Text('Log Out'))
          ]),
        ),
      ),
    );
  }
}
