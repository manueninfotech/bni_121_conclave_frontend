import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Error loading profile.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 24),
              _buildInfoTile('Name', data['name']),
              _buildInfoTile('Business', data['businessName']),
              _buildInfoTile('Category', data['businessCategory']),
              _buildInfoTile('Location', data['location']),
              _buildInfoTile('Identifier', data['identifier']),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).logout();
                  if (context.mounted) context.go('/login');
                },
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(String title, String? subtitle) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      subtitle: Text(subtitle ?? 'N/A', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
