import 'package:dio/dio.dart';

/// Pulls a readable message out of a Dio error, preferring the server's
/// `{ error: { code, message, requestId } }` envelope from
/// `AllExceptionsFilter`.
class ApiError implements Exception {
  ApiError(this.code, this.message, [this.statusCode]);

  final String code;
  final String message;
  final int? statusCode;

  factory ApiError.from(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      if (body is Map && body['error'] is Map) {
        final e = body['error'] as Map;
        return ApiError(
          (e['code'] as String?) ?? 'UNKNOWN',
          (e['message'] as String?) ?? error.message ?? 'Request failed',
          status,
        );
      }
      return ApiError('NETWORK_ERROR', error.message ?? 'Network error', status);
    }
    return ApiError('UNKNOWN', error.toString());
  }

  @override
  String toString() => '[$code${statusCode != null ? ' $statusCode' : ''}] $message';
}
