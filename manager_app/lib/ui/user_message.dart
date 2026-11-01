import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;

import '../api_client.dart';

/// Turns any error into a sentence a rider can act on; never leaks
/// exception text such as `ClientException: ...`.
String userMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is SocketException ||
      error is ClientException ||
      error is TimeoutException) {
    return "Can't reach the server. Check your connection and try again.";
  }
  return 'Something went wrong. Please try again.';
}
