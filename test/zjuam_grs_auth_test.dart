import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/http/zjuServices/zjuam.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_http_client.dart';

const _cacheKeyPrefix = 'zju_sso_cookie_';

void _seedCachedCookie(String username, String value) {
  FlutterSecureStorage.setMockInitialValues({
    '$_cacheKeyPrefix$username': jsonEncode({
      'value': value,
      'savedAt':
          DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    }),
  });
}

Uri _validateUri(String ticket) => Uri.https(
      'yjsy.zju.edu.cn',
      '/dataapi/sys/cas/client/validateLogin',
      {
        'ticket': ticket,
        'service': ZjuAm.graduateServiceUri.toString(),
      },
    );

ScriptedResponse _ticketResponse(String ticket) => ScriptedResponse(
      statusCode: HttpStatus.found,
      headers: {
        HttpHeaders.locationHeader:
            '${ZjuAm.graduateServiceUri}?ticket=$ticket',
      },
    );

ScriptedResponse _tokenResponse(String token) => ScriptedResponse(
      statusCode: HttpStatus.ok,
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      body: jsonEncode({
        'success': true,
        'result': {'token': token},
      }),
    );

final _loginUri = Uri.parse('https://zjuam.zju.edu.cn/cas/login');
final _pubKeyUri = Uri.parse('https://zjuam.zju.edu.cn/cas/v2/getPubKey');

void _expectPasswordLogin(
  ScriptedHttpClient client, {
  required String cookieValue,
}) {
  final modulus = List<String>.filled(128, 'f').join();
  client
    ..expectGet(
      _loginUri,
      ScriptedResponse(
        statusCode: HttpStatus.ok,
        headers: {HttpHeaders.contentTypeHeader: 'text/html'},
        cookies: [Cookie('JSESSIONID', 'form-session')],
        body: '<input name="execution" value="execution-1">',
      ),
    )
    ..expectGet(
      _pubKeyUri,
      ScriptedResponse(
        statusCode: HttpStatus.ok,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'modulus': modulus, 'exponent': '1'}),
      ),
    )
    ..expectPost(
      _loginUri,
      ScriptedResponse(
        statusCode: HttpStatus.found,
        cookies: [Cookie('iPlanetDirectoryPro', cookieValue)],
      ),
    );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('旧版持久化 SSO Cookie 被忽略并删除，启动使用密码新建会话', () async {
    const username = 'auth-test-ignore-legacy-cache';
    _seedCachedCookie(username, 'stale-persisted-cookie');

    final client = ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'fresh-process-cookie');

    final cookie = await ZjuAm.getSsoCookie(
      client,
      username,
      'test-password',
    );

    expect(cookie?.value, 'fresh-process-cookie');
    expect(
      client.requests.where(
          (request) => request.method == 'POST' && request.uri == _loginUri),
      hasLength(1),
    );
    expect(
      await const FlutterSecureStorage().read(key: '$_cacheKeyPrefix$username'),
      isNull,
    );
    expect(client.pendingDescriptions, isEmpty);
  });

  test('同一 HttpClient 的并发认证共享一次密码登录', () async {
    const username = 'auth-test-same-client-single-flight';
    final requestStarted = Completer<void>();
    final releaseResponse = Completer<void>();
    final modulus = List<String>.filled(128, 'f').join();
    final client = ScriptedHttpClient()
      ..expectGetAsync(_loginUri, (_) async {
        requestStarted.complete();
        await releaseResponse.future;
        return ScriptedResponse(
          statusCode: HttpStatus.ok,
          headers: {HttpHeaders.contentTypeHeader: 'text/html'},
          cookies: [Cookie('JSESSIONID', 'form-session')],
          body: '<input name="execution" value="execution-1">',
        );
      })
      ..expectGet(
        _pubKeyUri,
        ScriptedResponse(
          statusCode: HttpStatus.ok,
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'modulus': modulus, 'exponent': '1'}),
        ),
      )
      ..expectPost(
        _loginUri,
        ScriptedResponse(
          statusCode: HttpStatus.found,
          cookies: [Cookie('iPlanetDirectoryPro', 'shared-cookie')],
        ),
      );

    final first = ZjuAm.getSsoCookie(client, username, 'test-password');
    await requestStarted.future;
    final second = ZjuAm.getSsoCookie(client, username, 'test-password');
    releaseResponse.complete();

    final cookies = await Future.wait([first, second]);
    expect(cookies[0], isNotNull);
    expect(identical(cookies[0], cookies[1]), isTrue);
    expect(
      client.requests.where(
          (request) => request.method == 'POST' && request.uri == _loginUri),
      hasLength(1),
    );
    expect(client.pendingDescriptions, isEmpty);
  });

  test('Scholar 与校园卡的不同 HttpClient 不共享 SSO Cookie', () async {
    const username = 'auth-test-client-scoped';
    final scholarClient = ScriptedHttpClient();
    final ecardClient = ScriptedHttpClient();
    _expectPasswordLogin(scholarClient, cookieValue: 'scholar-cookie');
    _expectPasswordLogin(ecardClient, cookieValue: 'ecard-cookie');

    final scholarCookie = await ZjuAm.getSsoCookie(
      scholarClient,
      username,
      'test-password',
    );
    final ecardCookie = await ZjuAm.getSsoCookie(
      ecardClient,
      username,
      'test-password',
    );

    expect(scholarCookie?.value, 'scholar-cookie');
    expect(ecardCookie?.value, 'ecard-cookie');
    expect(identical(scholarCookie, ecardCookie), isFalse);
    expect(scholarClient.pendingDescriptions, isEmpty);
    expect(ecardClient.pendingDescriptions, isEmpty);
  });

  test('同一 HttpClient 短时间内复用刚建立的内存会话', () async {
    const username = 'auth-test-process-reuse';
    final client = ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'process-cookie');

    final first = await ZjuAm.getSsoCookie(client, username, 'test-password');
    final second = await ZjuAm.getSsoCookie(client, username, 'test-password');

    expect(first, isNotNull);
    expect(identical(first, second), isTrue);
    expect(client.pendingDescriptions, isEmpty);
  });

  test('清除登录态后同一 HttpClient 必须重新密码登录', () async {
    const username = 'auth-test-clear-process-cookie';
    final client = ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'first-cookie');
    _expectPasswordLogin(client, cookieValue: 'second-cookie');

    final first = await ZjuAm.getSsoCookie(client, username, 'test-password');
    await ZjuAm.clearCachedSsoCookie(username);
    final second = await ZjuAm.getSsoCookie(client, username, 'test-password');

    expect(first?.value, 'first-cookie');
    expect(second?.value, 'second-cookie');
    expect(client.pendingDescriptions, isEmpty);
  });

  test('研究生院只在实际登录时申请并立即兑换一张 CAS ticket', () async {
    const username = 'auth-test-graduate-just-in-time-ticket';
    const ticket = 'ST-just-in-time';
    final casUri = ZjuAm.buildServiceLoginUri(ZjuAm.graduateServiceUri);
    final client = ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'fresh-cookie');
    client
      ..expectGet(casUri, _ticketResponse(ticket))
      ..expectGet(_validateUri(ticket), _tokenResponse('graduate-token'));

    final cookie = await ZjuAm.getSsoCookie(client, username, 'test-password');
    await GrsNew().login(client, cookie);

    expect(
      client.requests.where((request) => request.uri == casUri),
      hasLength(1),
    );
    expect(client.pendingDescriptions, isEmpty);
  });
}
