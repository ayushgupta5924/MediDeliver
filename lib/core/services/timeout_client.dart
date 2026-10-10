import 'dart:async';
import 'package:http/http.dart' as http;

/// Bounds the entire HTTP exchange, including uploads and response bodies.
/// Aborting transport does not imply a server-side mutation was rolled back.
class TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration timeout;

  TimeoutClient({
    http.Client? inner,
    this.timeout = const Duration(seconds: 25),
  }) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abort = Completer<void>();
    final timer = Timer(timeout, abort.complete);
    final originalAbort = request is http.Abortable
        ? request.abortTrigger
        : null;
    final forwarded = _ForwardRequest(
      request,
      originalAbort == null
          ? abort.future
          : Future.any([abort.future, originalAbort]),
    );
    try {
      final response = await _inner.send(forwarded);
      Stream<List<int>> body() async* {
        try {
          yield* response.stream;
        } finally {
          timer.cancel();
        }
      }

      return http.StreamedResponse(
        body(),
        response.statusCode,
        contentLength: response.contentLength,
        request: request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      timer.cancel();
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

class _ForwardRequest extends http.BaseRequest with http.Abortable {
  final http.BaseRequest original;
  late final http.ByteStream _body;
  @override
  final Future<void> abortTrigger;

  _ForwardRequest(this.original, this.abortTrigger)
    : super(original.method, original.url) {
    // Multipart requests add their boundary header during finalization.
    _body = original.finalize();
    headers.addAll(original.headers);
    contentLength = original.contentLength;
    followRedirects = original.followRedirects;
    maxRedirects = original.maxRedirects;
    persistentConnection = original.persistentConnection;
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return _body;
  }
}
