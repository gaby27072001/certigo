import 'package:dio/dio.dart';
import 'package:core/core.dart';

import 'correlation_interceptor.dart';

/// Supplies a fresh access token for outbound requests. Implemented by the auth
/// feature (Entra External ID) and injected so `data` stays auth-agnostic.
typedef TokenProvider = Future<String?> Function();

/// Called when the API returns 401 so the app can trigger re-authentication.
typedef UnauthorizedHandler = Future<void> Function();

/// Sink for lightweight HTTP debug traces. Injected by the app (which passes
/// `debugPrint`) so `data` stays Flutter-free while still surfacing logs in
/// `flutter run` / `adb logcat`. Null in production paths that don't opt in.
typedef DebugLogger = void Function(String message);

/// Thin, configured Dio wrapper for the Certigo API.
///
/// Centralizes base URL, timeouts, bearer-token injection and uniform error
/// translation into typed [Failure]s. Feature repositories depend on this, not
/// on Dio directly.
class ApiClient {
  ApiClient({
    Dio? dio,
    required TokenProvider tokenProvider,
    UnauthorizedHandler? onUnauthorized,
    String? baseUrl,
    DebugLogger? debugLog,
    CorrelationIdGenerator? correlationIdGenerator,
  }) : _dio = dio ?? Dio(),
       _debugLog = debugLog {
    _dio.options
      ..baseUrl = baseUrl ?? AppEnv.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = 'application/json';

    // Stamp every request with an `x-correlation-id` so a single id links
    // client → backend → App Insights (ADR-013). Registered first so the id is
    // present before any other interceptor runs and can be traced below.
    _dio.interceptors.add(
      CorrelationIdInterceptor(generate: correlationIdGenerator, debugLog: debugLog),
    );

    // Trace HTTP requests/responses/errors so the login flow is visible in
    // `flutter run` / `adb logcat` — Dio rides on dart:io and emits nothing by
    // default. Registered first so the request is logged before token fetch.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          options.extra['__loginDbgStart'] = DateTime.now().microsecondsSinceEpoch;
          _debugLog?.call('[LOGIN-DBG] HTTP → ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
          final int ms = _elapsedMs(response.requestOptions);
          _debugLog?.call(
            '[LOGIN-DBG] HTTP ← ${response.statusCode} '
            '${response.requestOptions.path} (${ms}ms)',
          );
          handler.next(response);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) {
          final int ms = _elapsedMs(e.requestOptions);
          _debugLog?.call(
            '[LOGIN-DBG] HTTP ✗ ${e.type.name} ${e.requestOptions.path} '
            '(${ms}ms): ${e.message}',
          );
          handler.next(e);
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? normalizedToken = (await tokenProvider())?.trim();
          if (normalizedToken != null && normalizedToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $normalizedToken';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.response?.statusCode == 401 && onUnauthorized != null) {
            await onUnauthorized();
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio _dio;
  final DebugLogger? _debugLog;

  Future<Result<T>> getJson<T>(
    String path,
    T Function(Map<String, dynamic> json) parse, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() async {
      final Response<dynamic> res = await _dio.get<dynamic>(path, queryParameters: query);
      return parse(_asMap(res.data));
    });
  }

  Future<Result<T>> getJsonWithHeaders<T>(
    String path,
    T Function(Map<String, dynamic> json, Headers headers) parse, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() async {
      final Response<dynamic> res = await _dio.get<dynamic>(path, queryParameters: query);
      return parse(_asMap(res.data), res.headers);
    });
  }

  Future<Result<T>> postJson<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) parse, {
    Map<String, dynamic>? headers,
  }) async {
    return _guard(() async {
      final Response<dynamic> res = await _dio.post<dynamic>(
        path,
        data: body,
        options: headers == null ? null : Options(headers: headers),
      );
      return parse(_asMap(res.data));
    });
  }

  Future<Result<T>> deleteJson<T>(String path, T Function(Map<String, dynamic> json) parse) async {
    return _guard(() async {
      final Response<dynamic> res = await _dio.delete<dynamic>(path);
      return parse(_asMap(res.data));
    });
  }

  /// Runs [action], converting any exception into a typed [Failure].
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on DioException catch (e) {
      return Err<T>(_mapDioError(e));
    } on FormatException catch (_) {
      return const Err(ParseFailure());
    } catch (_) {
      return const Err(UnknownFailure());
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Expected a JSON object');
  }

  /// Milliseconds elapsed since the `onRequest` marker, or -1 if unavailable.
  static int _elapsedMs(RequestOptions options) {
    final Object? start = options.extra['__loginDbgStart'];
    if (start is int) {
      return ((DateTime.now().microsecondsSinceEpoch - start) / 1000).round();
    }
    return -1;
  }

  Failure _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkFailure();
    }
    final int? status = e.response?.statusCode;
    if (status == 401 || status == 403) return const AuthFailure();
    if (status == 404) return const NotFoundFailure();
    // Extract the RFC 9457 ProblemDetails `detail` field when the server sends one
    // (e.g. 503 Catalog unavailable). Surfaces actionable server messages to the UI.
    final String? detail = e.response?.data is Map<String, dynamic>
        ? (e.response!.data as Map<String, dynamic>)['detail'] as String?
        : null;
    if (status != null && status >= 500) {
      return ServerFailure(detail ?? 'Erreur serveur', statusCode: status);
    }
    return ServerFailure(detail ?? e.message ?? 'Requête échouée', statusCode: status);
  }
}
