import 'dart:async';
import 'package:dio/dio.dart';

/// Base exception class for Compozy API client errors.
class CompozyApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  CompozyApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  /// Factory to parse [DioException] into appropriate [CompozyApiException] subclass or instance.
  factory CompozyApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return CompozyTimeoutException(
          message: error.message ?? 'Connection timeout with CompozyOS daemon',
          duration: error.requestOptions.connectTimeout,
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.connectionError:
        return CompozyNetworkException(
          message: error.message ?? 'Failed to connect to CompozyOS daemon',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.badResponse:
        final response = error.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        String message = 'API request failed with status $statusCode';
        String? code;
        dynamic details;

        if (data is Map<String, dynamic>) {
          if (data['code'] is String) {
            code = data['code'] as String;
          }
          if (data['message'] is String) {
            message = data['message'] as String;
          } else if (data['error'] is String) {
            message = data['error'] as String;
          } else if (data['error'] is Map<String, dynamic>) {
            final errMap = data['error'] as Map<String, dynamic>;
            code ??= errMap['code'] as String?;
            if (errMap['message'] is String) {
              message = errMap['message'] as String;
            } else if (errMap['error'] is String) {
              message = errMap['error'] as String;
            }
            details ??= errMap['details'];
          } else if (data['detail'] is String) {
            message = data['detail'] as String;
          }

          details ??= data['details'];
        } else if (data is String && data.isNotEmpty) {
          message = data;
        }

        if (statusCode == 409 &&
            (code == 'session_busy' || message.toLowerCase().contains('busy'))) {
          return SessionBusyException(
            message: message,
            statusCode: statusCode,
            code: code,
            details: details,
          );
        }

        if (statusCode != null && statusCode >= 500) {
          return CompozyServerException(
            message: message,
            statusCode: statusCode,
            code: code,
            details: details,
          );
        }

        return CompozyApiException(
          message: message,
          statusCode: statusCode,
          code: code,
          details: details,
        );

      case DioExceptionType.cancel:
        return CompozyApiException(
          message: 'Request was cancelled',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.badCertificate:
        return CompozyApiException(
          message: 'Bad certificate',
          statusCode: error.response?.statusCode,
        );

      case DioExceptionType.unknown:
      default:
        return CompozyApiException(
          message: error.message ?? 'An unexpected error occurred',
          statusCode: error.response?.statusCode,
        );
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('CompozyApiException: $message');
    if (statusCode != null) buffer.write(' (Status: $statusCode)');
    if (code != null) buffer.write(' [Code: $code]');
    if (details != null) buffer.write(' Details: $details');
    return buffer.toString();
  }
}

/// Thrown when a request to CompozyOS daemon times out.
/// Implements [TimeoutException] for compatibility with standard async error checks.
class CompozyTimeoutException extends CompozyApiException implements TimeoutException {
  @override
  final Duration? duration;

  CompozyTimeoutException({
    required super.message,
    this.duration,
    super.statusCode,
    super.code,
    super.details,
  });
}

/// Thrown on network-level connectivity errors (e.g. connection refused, offline).
class CompozyNetworkException extends CompozyApiException {
  CompozyNetworkException({
    required super.message,
    super.statusCode,
    super.code,
    super.details,
  });
}

/// Thrown when CompozyOS daemon returns 5xx HTTP response.
class CompozyServerException extends CompozyApiException {
  CompozyServerException({
    required super.message,
    super.statusCode,
    super.code,
    super.details,
  });
}

/// Thrown when CompozyOS daemon returns 409 Session Busy.
class SessionBusyException extends CompozyApiException {
  SessionBusyException({
    super.message = 'Session is busy',
    super.statusCode = 409,
    super.code = 'session_busy',
    super.details,
  });
}
