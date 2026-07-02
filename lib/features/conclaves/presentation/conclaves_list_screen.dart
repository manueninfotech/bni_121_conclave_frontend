import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/conclave_model.dart';
import '../data/conclave_repository.dart';

class ConclavesListScreen extends ConsumerStatefulWidget {
  const ConclavesListScreen({super.key});

  @override
  ConsumerState<ConclavesListScreen> createState() => _ConclavesListScreenState();
}

class _ConclavesListScreenState extends ConsumerState<ConclavesListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conclavesAsyncValue = ref.watch(conclavesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conclaves'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ONGOING'),
            Tab(text: 'UPCOMING'),
            Tab(text: 'PAST'),
          ],
        ),
      ),
      body: conclavesAsyncValue.when(
        data: (conclaves) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(_getOngoing(conclaves)),
              _buildList(_getUpcoming(conclaves)),
              _buildList(_getPast(conclaves)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  List<Conclave> _getOngoing(List<Conclave> conclaves) => conclaves.where((c) => c.status == ConclaveStatus.running || c.status == ConclaveStatus.locked).toList();
  List<Conclave> _getUpcoming(List<Conclave> conclaves) => conclaves.where((c) => c.status == ConclaveStatus.registrationOpen || c.status == ConclaveStatus.registrationClosed || c.status == ConclaveStatus.draft || c.status == ConclaveStatus.snapshotted || c.status == ConclaveStatus.scheduled).toList();
  List<Conclave> _getPast(List<Conclave> conclaves) => conclaves.where((c) => c.status == ConclaveStatus.completed || c.status == ConclaveStatus.cancelled).toList();

  Widget _buildList(List<Conclave> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No conclaves found.'));
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {}); // Mock refresh
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final conclave = list[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conclave.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(conclave),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(conclave.venueLocation, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy - hh:mm a').format(conclave.date),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (conclave.isRegistered)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
                          onPressed: () => context.push('/conclaves/${conclave.id}'),
                          child: const Text('View Dashboard'),
                        )
                      else if (conclave.isRegistrationOpen)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
                          onPressed: () => context.push('/conclaves/${conclave.id}/register'),
                          child: const Text('Register'),
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(120, 40)),
                          onPressed: null,
                          child: const Text('Registration Closed'),
                        ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(Conclave conclave) {
    Color color;
    String text;

    if (conclave.status == ConclaveStatus.running) {
      color = Colors.green;
      text = 'LIVE';
    } else if (conclave.status == ConclaveStatus.completed) {
      color = Colors.grey;
      text = 'COMPLETED';
    } else {
      color = Colors.orange;
      text = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
