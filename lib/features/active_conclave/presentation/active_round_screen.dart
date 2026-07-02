import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/active_conclave_models.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';

class ActiveRoundScreen extends ConsumerStatefulWidget {
  final String conclaveId;
  
  const ActiveRoundScreen({super.key, required this.conclaveId});

  @override
  ConsumerState<ActiveRoundScreen> createState() => _ActiveRoundScreenState();
}

class _ActiveRoundScreenState extends ConsumerState<ActiveRoundScreen> {
  late ActiveRound _currentRound;
  late Timer _timer;
  Duration _timeRemaining = Duration.zero;
  bool _isTransitionPhase = false;
  
  // Assume user is captain for mock purposes to show full UI
  final bool _isCaptain = true; 
  final String _currentUserId = 'my_user_id'; // Mock

  @override
  void initState() {
    super.initState();
    _currentRound = mockActiveRound;
    _calculateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeRemaining());
    
    // Start background sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).startSyncTimer(widget.conclaveId);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    final now = DateTime.now();
    final roundEndTime = _currentRound.startTime.add(_currentRound.activeDuration);
    final transitionEndTime = roundEndTime.add(_currentRound.transitionDuration);

    if (now.isBefore(roundEndTime)) {
      _isTransitionPhase = false;
      _timeRemaining = roundEndTime.difference(now);
    } else if (now.isBefore(transitionEndTime)) {
      _isTransitionPhase = true;
      _timeRemaining = transitionEndTime.difference(now);
    } else {
      _timeRemaining = Duration.zero;
      // Round is over
    }
    setState(() {});
  }

  void _toggleAttendance(TableSeat seat, bool? value) async {
    if (value == null) return;
    
    setState(() {
      seat.isPresent = value;
    });

    try {
      await ref.read(localDbProvider).markAttendance(
        conclaveId: widget.conclaveId,
        roundNumber: _currentRound.roundNumber,
        tableNumber: _currentRound.tableNumber,
        userId: seat.userId,
        isPresent: value,
      );
      // Optional: show subtle success or rely on background sync
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save attendance locally')),
        );
      }
    }
  }

  void _giveReferral(TableSeat seat) {
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Give Referral to \${seat.name}'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'e.g. Call my friend John at 555-1234',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(localDbProvider).addReferral(
                  conclaveId: widget.conclaveId,
                  roundNumber: _currentRound.roundNumber,
                  fromUserId: _currentUserId,
                  toUserId: seat.userId,
                  notes: notesController.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Referral to ${seat.name} saved offline!')),
                  );
                }
              } catch (e) {
                 if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save referral')),
                  );
                 }
              }
            },
            child: const Text('Give Referral'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final timerColor = _isTransitionPhase ? Colors.orange : Colors.green;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${_currentRound.roundNumber} - Table ${_currentRound.tableNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Manual Sync',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data with backend...')),
              );
              await ref.read(syncServiceProvider).syncNow(widget.conclaveId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync completed!')),
                );
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Timer Header
          Container(
            padding: const EdgeInsets.all(24),
            color: timerColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isTransitionPhase ? Icons.directions_walk : Icons.timer, 
                  color: timerColor,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTransitionPhase ? 'TRANSITION' : 'ACTIVE ROUND',
                      style: TextStyle(
                        color: timerColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _formatDuration(_timeRemaining),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Instruction banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[200],
            child: Text(
              _isCaptain 
                  ? 'Captain: Please mark attendance below.' 
                  : 'Connect with your table members!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ),

          // Members List
          Expanded(
            child: ListView.separated(
              itemCount: _currentRound.seats.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final seat = _currentRound.seats[index];
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: _isCaptain 
                      ? Checkbox(
                          value: seat.isPresent,
                          onChanged: (v) => _toggleAttendance(seat, v),
                          activeColor: Theme.of(context).primaryColor,
                        )
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          child: Text(seat.name.substring(0, 1), style: TextStyle(color: Theme.of(context).primaryColor)),
                        ),
                  title: Text(seat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('\${seat.businessName} • \${seat.category}', style: const TextStyle(fontSize: 12)),
                  trailing: seat.userId != _currentUserId
                      ? IconButton(
                          icon: const Icon(Icons.handshake),
                          color: Colors.green,
                          tooltip: 'Give Referral',
                          onPressed: () => _giveReferral(seat),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
