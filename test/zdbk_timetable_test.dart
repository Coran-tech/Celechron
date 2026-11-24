import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/zdbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'scripted_http_client.dart';

class _Cache extends DatabaseHelper {
  final pages = <String, String>{};
  @override
  String? getCachedWebPage(String key) => pages[key];
  @override
  Future<void> setCachedWebPage(String key, String value) async =>
      pages[key] = value;
}

final timetable =
    Uri.https('zdbk.zju.edu.cn', '/jwglxt/kbcx/xskbcx_cxXsKb.html');
const row = {'kcb': '数学<br>班<br>师<br>室zwf', 'djj': 1, 'skcd': 2, 'xxq': '秋'};
ScriptedResponse response(String body, [int status = 200]) => ScriptedResponse(
    statusCode: status,
    headers: {'content-type': 'application/json'},
    body: body);

Future<void> login(Zdbk api, ScriptedHttpClient client) async {
  final target =
      Uri.https('zdbk.zju.edu.cn', '/jwglxt/xtgl/login_ssologin.html');
  client
    ..expectGet(
        Uri.https(
            'zjuam.zju.edu.cn', '/cas/login', {'service': target.toString()}),
        ScriptedResponse(
            statusCode: 302, headers: {'location': target.toString()}))
    ..expectGet(
        target,
        ScriptedResponse(
            statusCode: 200,
            cookies: [Cookie('JSESSIONID', 'fake'), Cookie('route', 'fake')]));
  await api.login(client, Cookie('iPlanetDirectoryPro', 'fake'));
}

void main() {
  for (final empty in ['null', '{"kbList":[]}']) {
    test('未来学期 $empty：首次和当天再次刷新都保留上次课表', () async {
      final client = ScriptedHttpClient();
      final db = _Cache();
      final api = Zdbk()..db = db;
      await login(api, client);
      final year = DateTime.now().year + 1;
      final term = '$year-${year + 1}';
      final key = 'zdbk_Timetable${term}1|秋';
      final raw = jsonEncode([row]);
      db.pages[key] = raw;
      client.expectPost(timetable, response(empty));
      for (var i = 0; i < 2; i++) {
        final result = await api.getTimetable(client, term, '1|秋');
        expect(result.item1, isNull);
        expect(result.item2.single.name, '数学');
      }
      expect(db.pages[key], raw);
      expect(client.requests.where((r) => r.method == 'POST'), hasLength(1));
    });
  }

  test('历史课表仅复用学年结束后写入的非空缓存', () async {
    final db = _Cache();
    final client = ScriptedHttpClient();
    final api = Zdbk()..db = db;
    await login(api, client);
    const key = 'zdbk_Timetable2020-20211|秋';
    db.pages[key] = jsonEncode([row]);
    db.pages['${key}_timestamp'] = DateTime(2021, 8, 15).toIso8601String();
    client.expectPost(
        timetable,
        response(jsonEncode({
          'kbList': [
            {...row, 'djj': 3}
          ]
        })));
    for (var i = 0; i < 2; i++) {
      final result =
          await api.getTimetable(client, '2020-2021', '1|秋', preferCache: true);
      expect(result.item1, isNull);
      expect(result.item2.single.time, [3, 4]);
    }
    expect(client.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  test('921 退避后恢复；排队的另一个季度不插队', () async {
    final db = _Cache();
    final client = ScriptedHttpClient();
    final api = Zdbk()..db = db;
    await login(api, client);
    client
      ..expectPost(timetable, response('too frequent', 921))
      ..expectPost(
          timetable,
          response(jsonEncode({
            'kbList': [row]
          })))
      ..expectPost(timetable, response('{"kbList":[]}'));
    final results = await Future.wait([
      api.getTimetable(client, '2020-2021', '1|秋'),
      api.getTimetable(client, '2020-2021', '1|冬'),
    ]);
    expect(results.map((r) => r.item1), everyElement(isNull));
    expect(results.first.item2.single.name, '数学');
    expect(results.last.item2, isEmpty);
    expect(
        client.requests
            .where((r) => r.method == 'POST')
            .map((r) => utf8.decode(r.body).split('&')[1]),
        ['xqm=1|秋', 'xqm=1|秋', 'xqm=1|冬']);
  });
}
