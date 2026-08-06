// lib/core/network/api_exception.dart

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({String message = 'Network connection failed. Please check internet connection.'})
      : super(message: message, statusCode: 0);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String message = 'Unauthorized access. Please login again.'})
      : super(message: message, statusCode: 401);
}

class NotFoundException extends ApiException {
  NotFoundException({String message = 'Requested resource not found.'})
      : super(message: message, statusCode: 404);
}

class ServerException extends ApiException {
  ServerException({String message = 'Server error occurred. Please try again later.'})
      : super(message: message, statusCode: 500);
}
