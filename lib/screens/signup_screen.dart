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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Passwords do not match')));
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
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Signup failed')));
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
            child: Column(
              children: [
                // 🔹 Logo above the white box
                Image.asset(
                  'assets/logo3.png',
                  height: 120,
                ),
                const SizedBox(height: 20),

                // 🔹 White rounded container
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter your full name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter your email',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pwCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter your password',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pwConfirmCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Confirm password',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Create Account'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/login'),
                        child: const Text(
                          "Already have an account?" 'Sign in',
                        ),
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
}
