import 'dart:async';

import 'package:flutter/foundation.dart';

import 'json_cache.dart';

/// A stream of a backend resource that works offline:
///
///  1. emits the cached copy immediately (if any),
///  2. fetches the live copy, emits it and caches it,
///  3. refetches every [refresh] while someone is listening.
///
/// A failed fetch is logged, not thrown, as long as something was shown — at a
/// venue with no network the last good copy is the right answer. Only when
/// there is neither a cache nor a network does the stream report an error.
Stream<T> cachedStream<T>({
  required String cacheKey,
  required Future<Object?> Function() fetch,
  required T Function(Object? json) parse,
  Duration refresh = const Duration(seconds: 30),
}) {
  late final StreamController<T> controller;
  Timer? timer;
  var emitted = false;

  Future<void> load() async {
    try {
      final json = await fetch();
      await JsonCache.write(cacheKey, json);
      if (!controller.isClosed) {
        controller.add(parse(json));
        emitted = true;
      }
    } catch (e) {
      debugPrint('[$cacheKey] refresh failed: $e');
      if (!emitted && !controller.isClosed) controller.addError(e);
    }
  }

  controller = StreamController<T>(
    onListen: () async {
      final cached = await JsonCache.read(cacheKey);
      if (cached != null && !controller.isClosed) {
        try {
          controller.add(parse(cached));
          emitted = true;
        } catch (e) {
          debugPrint('[$cacheKey] cached copy unreadable: $e');
        }
      }
      await load();
      timer = Timer.periodic(refresh, (_) => load());
    },
    onCancel: () => timer?.cancel(),
  );
  return controller.stream;
}
