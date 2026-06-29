import 'package:dio/dio.dart';
import 'package:core/core.dart';

/// Supplies a fresh access token for outbound requests. Implemented by the auth
/// feature (Entra External ID) and injected so `data` stays auth-agnostic.
typedef TokenProvider = Future<String?> Function();

/// Called when the API returns 401 so the app can trigger re-authentication.
typedef UnauthorizedHandler = Future<void> Function();

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
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl ?? AppEnv.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? token = await tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
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

  Future<Result<T>> postJson<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    return _guard(() async {
      final Response<dynamic> res = await _dio.post<dynamic>(path, data: body);
      return parse(_asMap(res.data));
    });
  }

  Future<Result<T>> deleteJson<T>(
    String path,
    T Function(Map<String, dynamic> json) parse,
  ) async {
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

  Failure _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkFailure();
    }
    final int? status = e.response?.statusCode;
    if (status == 401 || status == 403) return const AuthFailure();
    if (status == 404) return const NotFoundFailure();
    if (status != null && status >= 500) {
      return ServerFailure('Erreur serveur', statusCode: status);
    }
    return ServerFailure(e.message ?? 'Requête échouée', statusCode: status);
  }
}
