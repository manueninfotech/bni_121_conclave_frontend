import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'json_cache.dart';

/// One conclave's document, kept current — the replacement for listening to
/// `conclaves/{id}` in Firestore.
///
///  - Emits the cached copy first (works with no network at the venue).
///  - Fetches the full document (`GET /conclaves/:id`) and caches it.
///  - Holds a Server-Sent Events stream (`GET /conclaves/:id/live`): each push
///    carries the live round state (status, current round, start time, pause),
///    which is merged into the document and emitted at once. When the schedule
///    or status changes, the full document is refetched.
///  - Reconnects with backoff when the connection drops, and refetches on
///    reconnect so nothing missed while offline is lost.
Stream<Map<String, dynamic>> watchConclaveDoc(String conclaveId) {
  late final StreamController<Map<String, dynamic>> controller;
  final cacheKey = 'conclave:$conclaveId';
  Map<String, dynamic>? doc;
  CancelToken? cancel;
  var closed = false;
  var attempt = 0;

  void emit() {
    if (doc != null && !controller.isClosed) controller.add(Map<String, dynamic>.from(doc!));
  }

  Future<void> fetchFull() async {
    try {
      final fresh = await ApiClient.instance.getJson('/conclaves/$conclaveId');
      doc = fresh;
      await JsonCache.write(cacheKey, fresh);
      emit();
    } catch (e) {
      debugPrint('[conclave $conclaveId] fetch failed: $e');
      if (doc == null && !controller.isClosed) controller.addError(e);
    }
  }

  void applyLive(Map<String, dynamic> state) {
    final current = doc;
    if (current == null) return;
    final needsFull = current['status'] != state['status'] ||
        current['isScheduleLocked'] != state['isScheduleLocked'];
    for (final k in const [
      'status',
      'currentRound',
      'currentRoundStartedAt',
      'isRoundPaused',
      'roundPausedAt',
      'roundElapsedMsBeforePause',
      'isScheduleLocked',
      'isRegistrationOpen',
      'updatedAt',
      // Round clock inputs (see round_clock.dart).
      'roundCount',
      'personsPerTable',
      'roundProgressionMode',
      'roundExtensionSeconds',
      'moveSeconds',
    ]) {
      if (state.containsKey(k)) current[k] = state[k];
    }
    emit();
    unawaited(JsonCache.write(cacheKey, current));
    if (needsFull) unawaited(fetchFull());
  }

  Future<void> listenLive() async {
    while (!closed) {
      cancel = CancelToken();
      try {
        final res = await ApiClient.instance.dio.get<ResponseBody>(
          '/conclaves/$conclaveId/live',
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            // The server sends a heartbeat every 25s; silence beyond this means a dead link.
            receiveTimeout: const Duration(seconds: 70),
          ),
        );
        if (attempt > 0) unawaited(fetchFull()); // catch up on anything missed
        attempt = 0;
        var buffer = '';
        await for (final chunk in res.data!.stream.cast<List<int>>().transform(utf8.decoder)) {
          buffer += chunk;
          int i;
          while ((i = buffer.indexOf('\n\n')) >= 0) {
            final frame = buffer.substring(0, i);
            buffer = buffer.substring(i + 2);
            final data = frame.split('\n').where((l) => l.startsWith('data: ')).map((l) => l.substring(6)).join();
            if (data.isEmpty || data == 'null') continue;
            try {
              applyLive(Map<String, dynamic>.from(jsonDecode(data) as Map));
            } catch (e) {
              debugPrint('[conclave $conclaveId] bad live frame: $e');
            }
          }
        }
      } catch (e) {
        if (closed) return;
        debugPrint('[conclave $conclaveId] live stream dropped: $e');
      }
      if (closed) return;
      attempt++;
      final waitMs = min(30000, 1000 * pow(2, min(attempt, 5)).toInt());
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }
  }

  controller = StreamController<Map<String, dynamic>>(
    onListen: () async {
      final cached = await JsonCache.read(cacheKey);
      if (cached is Map) {
        doc = Map<String, dynamic>.from(cached);
        emit();
      }
      await fetchFull();
      unawaited(listenLive());
    },
    onCancel: () {
      closed = true;
      cancel?.cancel();
    },
  );
  return controller.stream;
}

/// One-shot read of a conclave document: network if possible, else the cache.
Future<Map<String, dynamic>?> readConclaveDoc(String conclaveId) async {
  final cacheKey = 'conclave:$conclaveId';
  try {
    final fresh = await ApiClient.instance.getJson('/conclaves/$conclaveId');
    await JsonCache.write(cacheKey, fresh);
    return fresh;
  } catch (_) {
    final cached = await JsonCache.read(cacheKey);
    return cached is Map ? Map<String, dynamic>.from(cached) : null;
  }
}
