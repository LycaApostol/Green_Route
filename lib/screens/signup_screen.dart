import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Signup failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signUpWithGitHub() async {
    try {
      GithubAuthProvider githubProvider = GithubAuthProvider();
      final userCredential = await FirebaseAuth.instance.signInWithProvider(githubProvider);
      
      // Create user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': userCredential.user?.displayName ?? 'GitHub User',
        'email': userCredential.user?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub sign-up failed')),
        );
      }
    }
  }

  Future<void> _signUpWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      
      if (result.status == LoginStatus.success) {
        final OAuthCredential credential = 
            FacebookAuthProvider.credential(result.accessToken!.token);
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        
        // Create user document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': userCredential.user?.displayName ?? 'Facebook User',
          'email': userCredential.user?.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Facebook sign-up cancelled: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facebook sign-up failed')),
        );
      }
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
                // Logo above the white box
                Image.asset(
                  'assets/logo3.png',
                  height: 120,
                ),
                const SizedBox(height: 20),

                // White rounded container
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pwCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pwConfirmCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outlined),
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
                                color: Colors.white,
                              )
                            : const Text('Create Account'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text('Already have an account? Sign in'),
                      ),
                      const Divider(),
                      const Text('Or sign up with'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _signUpWithGitHub,
                              icon: const Icon(Icons.code, size: 20),
                              label: const Text('GitHub'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF24292e),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _signUpWithFacebook,
                              icon: const Icon(Icons.facebook, size: 20),
                              label: const Text('Facebook'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1877F2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }
}