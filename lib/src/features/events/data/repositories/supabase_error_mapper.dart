import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/network_exception.dart'
    if (dart.library.io) '../../../../core/errors/network_exception_io.dart';

class SupabaseErrorMapper {
  const SupabaseErrorMapper._();

  static const _authorizationCodes = {
    '401',
    '403',
    '42501',
    '28000',
    '28P01',
    'PGRST301',
    'PGRST302',
  };

  static AppException map(Object error) {
    if (error is AppException) {
      return error;
    }

    if (error is TimeoutException) {
      return AppException(type: AppErrorType.timeout, cause: error);
    }

    if (isNetworkException(error)) {
      return AppException(type: AppErrorType.network, cause: error);
    }

    if (error is AuthException) {
      return AppException(type: AppErrorType.authorization, cause: error);
    }

    if (error is PostgrestException) {
      final code = error.code?.toUpperCase();
      final type = _authorizationCodes.contains(code)
          ? AppErrorType.authorization
          : AppErrorType.validationOrServer;
      return AppException(type: type, cause: error);
    }

    if (error is FormatException || error is StateError) {
      return AppException(type: AppErrorType.validationOrServer, cause: error);
    }

    return AppException(type: AppErrorType.unknown, cause: error);
  }
}
