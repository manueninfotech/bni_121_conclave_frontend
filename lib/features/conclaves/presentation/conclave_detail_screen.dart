import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/conclave_model.dart';

class ConclaveDetailScreen extends ConsumerStatefulWidget {
  final String conclaveId;
  
  const ConclaveDetailScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ConclaveDetailScreen> createState() => _ConclaveDetailScreenState();
}

class _ConclaveDetailScreenState extends ConsumerState<ConclaveDetailScreen> {
  late Conclave _conclave;

  @override
  void initState() {
    super.initState();
    _conclave = mockConclaves.firstWhere((c) => c.id == widget.conclaveId, orElse: () => mockConclaves.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conclave Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _conclave.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.location_on, 'Venue', _conclave.venueLocation),
                    const Divider(),
                    _buildInfoRow(Icons.calendar_today, 'Date', _conclave.date.toString().split('.')[0]),
                    const Divider(),
                    _buildInfoRow(
                      Icons.person, 
                      'Your Role', 
                      _conclave.userRole?.name.toUpperCase() ?? 'PENDING ASSIGNMENT',
                    ),
                    if (_conclave.userRole == ConclaveRole.captain && _conclave.userTableNumber != null) ...[
                      const Divider(),
                      _buildInfoRow(
                        Icons.table_restaurant, 
                        'Assigned Table', 
                        'Table ${_conclave.userTableNumber}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            if (_conclave.status == ConclaveStatus.locked || _conclave.status == ConclaveStatus.scheduled)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Waiting for Admin to Start...',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'The conclave schedule is ready. Please wait at the venue for the admin to begin Round 1.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            
            if (_conclave.status == ConclaveStatus.running)
              ElevatedButton(
                onPressed: () {
                  context.push('/conclaves/${_conclave.id}/active');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Enter Active Round', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
