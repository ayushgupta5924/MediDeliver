import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medideliver/core/services/auth_service.dart';
import 'package:medideliver/core/services/timeout_client.dart';

class StalledClient extends http.BaseClient {
  final bool headersReceived;
  StalledClient({this.headersReceived = false});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abort = (request as http.Abortable).abortTrigger!;
    if (!headersReceived) {
      await abort;
      throw http.RequestAbortedException(request.url);
    }
    final body = StreamController<List<int>>();
    unawaited(
      abort.then((_) {
        body.addError(http.RequestAbortedException(request.url));
        unawaited(body.close());
      }),
    );
    return http.StreamedResponse(body.stream, 200);
  }
}

void main() {
  for (final headersReceived in [false, true]) {
    test(
      'stalled HTTP exchange is aborted (headers: $headersReceived)',
      () async {
        final client = TimeoutClient(
          inner: StalledClient(headersReceived: headersReceived),
          timeout: const Duration(milliseconds: 10),
        );
        addTearDown(client.close);
        await expectLater(
          client.get(Uri.https('example.invalid', '/')),
          throwsA(isA<http.RequestAbortedException>()),
        );
      },
    );
  }

  test('caller cancellation survives the timeout wrapper', () async {
    final client = TimeoutClient(inner: StalledClient());
    addTearDown(client.close);
    final abort = Completer<void>();
    final result = client.send(
      http.AbortableRequest(
        'POST',
        Uri.https('example.invalid', '/'),
        abortTrigger: abort.future,
      ),
    );
    final expectation = expectLater(
      result,
      throwsA(isA<http.RequestAbortedException>()),
    );
    abort.complete();
    await expectation;
  });

  test('normal request body and headers are preserved', () async {
    final client = TimeoutClient(
      inner: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['x-test'], 'present');
        expect(request.body, 'payload');
        return http.Response('response', 201, headers: {'x-result': 'ok'});
      }),
    );
    addTearDown(client.close);
    final response = await client.post(
      Uri.https('example.invalid', '/'),
      headers: {'x-test': 'present'},
      body: 'payload',
    );
    expect(response.statusCode, 201);
    expect(response.body, 'response');
    expect(response.headers['x-result'], 'ok');
  });

  test('network failures never display raw URLs and provider internals', () {
    final error = AuthRetryableFetchException(
      message: 'Failed to fetch secret/internal/url',
    );
    expect(authErrorMessage(error), contains('try another network'));
    expect(authErrorMessage(error), isNot(contains('secret')));
    expect(
      authErrorMessage(
        const AuthException('internal server error', statusCode: '500'),
      ),
      isNot(contains('internal server error')),
    );
    expect(
      authErrorMessage(const AuthException('rate limit', statusCode: '429')),
      contains('Wait a minute'),
    );
  });
}
