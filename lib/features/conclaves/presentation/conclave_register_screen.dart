import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/conclave_repository.dart';

class ConclaveRegisterScreen extends ConsumerStatefulWidget {
  final String conclaveId;
  const ConclaveRegisterScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ConclaveRegisterScreen> createState() => _ConclaveRegisterScreenState();
}

class _ConclaveRegisterScreenState extends ConsumerState<ConclaveRegisterScreen> {
  bool _isSubmitting = false;

  void _confirmRegistration() async {
    setState(() => _isSubmitting = true);
    
    try {
      await ref.read(conclaveRepositoryProvider).registerForConclave(widget.conclaveId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully registered for conclave!')),
        );
        context.go('/conclaves');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conclavesAsync = ref.watch(conclavesStreamProvider);
    
    return conclavesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (conclaves) {
        final conclave = conclaves.firstWhere(
          (c) => c.id == widget.conclaveId, 
          orElse: () => conclaves.first,
        );

        return Scaffold(
          appBar: AppBar(
        title: const Text('Confirm Registration'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.event_available, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              Text(
                'Register for ${conclave.name}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${conclave.venueLocation} • ${conclave.date.month}/${conclave.date.day}/${conclave.date.year}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Your Profile Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(),
                      const ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Samba'), // Mock user name
                        subtitle: Text('Software Development'), // Mock category
                        contentPadding: EdgeInsets.zero,
                      ),
                      const ListTile(
                        leading: Icon(Icons.business),
                        title: Text('Manuen Infotech'), // Mock business
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmRegistration,
                child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Registration', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
    },
    );
  }
}
