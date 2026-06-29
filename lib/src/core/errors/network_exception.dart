import 'package:http/http.dart';

bool isNetworkException(Object error) => error is ClientException;
