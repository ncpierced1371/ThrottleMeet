import 'dart:io';

import 'package:http/http.dart';

bool isNetworkException(Object error) {
  return error is SocketException || error is ClientException;
}
