import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/conclave_model.dart';
import '../data/conclave_repository.dart';

class ConclaveDetailScreen extends ConsumerStatefulWidget {
  final String conclaveId;
  
  const ConclaveDetailScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ConclaveDetailScreen> createState() => _ConclaveDetailScreenState();
}

class _ConclaveDetailScreenState extends ConsumerState<ConclaveDetailScreen> {

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
            title: const Text('Conclave Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conclave.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.location_on, 'Venue', conclave.venueLocation),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('MMM dd, yyyy - hh:mm a').format(conclave.date)),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.people, 
                  'Status', 
                  conclave.status.name.toUpperCase(),
                ),
                const SizedBox(height: 24),
                if (conclave.isRegistered) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('My Participation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.badge, 'Role', conclave.userRole?.name.toUpperCase() ?? 'N/A'),
                  _buildInfoRow(Icons.table_restaurant, 'Table Number', conclave.userTableNumber?.toString() ?? 'TBD'),
                ],
                const SizedBox(height: 32),
                
                // Actions based on status
                if (conclave.status == ConclaveStatus.registrationOpen && !conclave.isRegistered)
                  ElevatedButton(
                    onPressed: () {
                      context.push('/conclaves/${conclave.id}/register');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Register Now', style: TextStyle(fontSize: 18)),
                  ),
                
                if (conclave.status == ConclaveStatus.running)
                  ElevatedButton(
                    onPressed: () {
                      context.push('/conclaves/${conclave.id}/active');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Enter Active Round', style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
