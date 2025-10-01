import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _createAccount() async {
    if (_pwCtrl.text != _pwConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pushReplacementNamed(context, '/map');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Signup failed')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2ECC71),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text('Create Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Enter your full name')),
                  SizedBox(height: 8),
                  TextField(controller: _emailCtrl, decoration: InputDecoration(hintText: 'Enter your email')),
                  SizedBox(height: 8),
                  TextField(controller: _pwCtrl, obscureText: true, decoration: InputDecoration(hintText: 'Enter your password')),
                  SizedBox(height: 8),
                  TextField(controller: _pwConfirmCtrl, obscureText: true, decoration: InputDecoration(hintText: 'Confirm password')),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(double.infinity, 44)),
                    child: _loading ? CircularProgressIndicator(color: Colors.white) : Text('Create Account'),
                  ),
                  SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: Text('Already have an account? Sign in')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
