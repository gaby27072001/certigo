import 'dart:math';

import 'package:dio/dio.dart';

/// HTTP header that carries the request correlation id end-to-end (ADR-013).
///
/// The backend (`ExceptionMiddleware`) is the authoritative correlation point:
/// it honours an inbound `x-correlation-id` when present and otherwise mints its
/// own. This interceptor makes the mobile client the *first* emitter so a single
/// id links client → backend → App Insights traces/logs, instead of the backend
/// having to invent one per request.
const String kCorrelationIdHeader = 'x-correlation-id';

/// Produces a correlation id. Injectable so tests can pin the value.
typedef CorrelationIdGenerator = String Function();

/// Generates a 32-char lowercase hexadecimal id.
///
/// The shape matches the backend's `Guid.NewGuid().ToString("n")` (32 hex chars,
/// no dashes) so the same id is visually identical on both sides of the wire and
/// in App Insights. Pure Dart — no `uuid` dependency required. The default source
/// is [Random.secure]: an unseeded `Random()` is seeded from 32 bits, so every id
/// it produced came from at most 2^32 distinct sequences despite its 128-bit look.
String generateCorrelationId([Random? random]) {
  final rng = random ?? Random.secure();
  const hex = '0123456789abcdef';
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(hex[rng.nextInt(16)]);
  }
  return buffer.toString();
}

/// Dio interceptor that stamps every outbound request with an
/// `x-correlation-id` header.
///
/// If the caller (or a replayed sync action) already set the header it is
/// preserved, so a logical operation keeps a stable id across retries; otherwise
/// a fresh id is minted. Registered first on the [Dio] chain so downstream
/// interceptors and debug traces can observe the id. Pure Dart, no Flutter
/// dependency.
class CorrelationIdInterceptor extends Interceptor {
  CorrelationIdInterceptor({
    CorrelationIdGenerator? generate,
    void Function(String message)? debugLog,
  })  : _generate = generate ?? generateCorrelationId,
        _debugLog = debugLog;

  final CorrelationIdGenerator _generate;
  final void Function(String message)? _debugLog;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final existing = options.headers[kCorrelationIdHeader];
    final correlationId = (existing is String && existing.isNotEmpty) ? existing : _generate();
    options.headers[kCorrelationIdHeader] = correlationId;
    _debugLog?.call('[cid] ${options.method} ${options.path} → $correlationId');
    handler.next(options);
  }
}
