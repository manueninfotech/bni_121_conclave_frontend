import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/conclave_model.dart';

class ConclaveRegisterScreen extends ConsumerStatefulWidget {
  final String conclaveId;
  const ConclaveRegisterScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ConclaveRegisterScreen> createState() => _ConclaveRegisterScreenState();
}

class _ConclaveRegisterScreenState extends ConsumerState<ConclaveRegisterScreen> {
  late Conclave _conclave;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _conclave = mockConclaves.firstWhere((c) => c.id == widget.conclaveId, orElse: () => mockConclaves.first);
  }

  void _confirmRegistration() async {
    setState(() => _isSubmitting = true);
    
    // TODO: Implement actual registration logic via API
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully registered for conclave!')),
      );
      // Mock local state update would happen here
      context.go('/conclaves');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Register for',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                _conclave.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
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
  }
}
