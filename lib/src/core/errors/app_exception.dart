enum AppErrorType {
  network,
  timeout,
  authorization,
  validationOrServer,
  unknown,
}

class AppException implements Exception {
  const AppException({required this.type, required this.cause});

  final AppErrorType type;
  final Object cause;

  @override
  String toString() => 'AppException(type: $type, cause: $cause)';
}
