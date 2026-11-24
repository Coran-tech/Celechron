import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

typedef ResponseFactory = FutureOr<HttpClientResponse> Function(
  ScriptedRequest request,
);

class _ExpectedExchange {
  final String method;
  final Uri uri;
  final ResponseFactory responseFactory;

  _ExpectedExchange(this.method, this.uri, this.responseFactory);

  String get description => '$method $uri';
}

class ScriptedHttpClient implements HttpClient {
  final Queue<_ExpectedExchange> _pending = Queue<_ExpectedExchange>();
  final List<ScriptedRequest> requests = <ScriptedRequest>[];

  List<String> get pendingDescriptions =>
      _pending.map((exchange) => exchange.description).toList(growable: false);

  void expectGet(Uri uri, HttpClientResponse response) {
    expectGetAsync(uri, (_) => response);
  }

  void expectGetAsync(Uri uri, ResponseFactory responseFactory) {
    _pending.add(_ExpectedExchange('GET', uri, responseFactory));
  }

  void expectPost(Uri uri, HttpClientResponse response) {
    _pending.add(_ExpectedExchange('POST', uri, (_) => response));
  }

  Future<HttpClientRequest> _open(String method, Uri uri) async {
    if (_pending.isEmpty) {
      throw StateError('Unexpected HTTP request: $method $uri');
    }
    final expected = _pending.removeFirst();
    if (expected.method != method || expected.uri != uri) {
      throw StateError(
        'Unexpected HTTP request: $method $uri; expected ${expected.description}',
      );
    }
    final request = ScriptedRequest(method, uri, expected.responseFactory);
    requests.add(request);
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClient call: $invocation');
}

class ScriptedRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final ResponseFactory _responseFactory;
  @override
  final List<Cookie> cookies = <Cookie>[];
  @override
  final HttpHeaders headers = _TestHttpHeaders();
  final List<int> body = <int>[];

  bool _followRedirects = true;
  bool _closed = false;

  ScriptedRequest(this.method, this.uri, this._responseFactory);

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) => _followRedirects = value;

  @override
  void add(List<int> data) => body.addAll(data);

  @override
  Future<HttpClientResponse> close() async {
    if (_closed) throw StateError('HTTP request closed twice: $method $uri');
    _closed = true;
    return await _responseFactory(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClientRequest call: $invocation');
}

class ScriptedResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  @override
  final int statusCode;
  @override
  final HttpHeaders headers;
  @override
  final List<Cookie> cookies;
  final int _bodyLength;

  ScriptedResponse({
    required this.statusCode,
    Map<String, String> headers = const {},
    List<Cookie> cookies = const [],
    String body = '',
  })  : headers = _TestHttpHeaders(headers),
        cookies = List<Cookie>.from(cookies),
        _bodyLength = utf8.encode(body).length,
        super(Stream<List<int>>.fromIterable([utf8.encode(body)]));

  @override
  int get contentLength => _bodyLength;

  @override
  bool get isRedirect =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  @override
  String get reasonPhrase => '';

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClientResponse call: $invocation');
}

class _TestHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};
  ContentType? _contentType;

  _TestHttpHeaders([Map<String, String> initial = const {}]) {
    for (final entry in initial.entries) {
      set(entry.key, entry.value);
    }
  }

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
    if (value == null) {
      _values.remove(HttpHeaders.contentTypeHeader);
    } else {
      _values[HttpHeaders.contentTypeHeader] = <String>[value.toString()];
    }
  }

  @override
  List<String>? operator [](String name) {
    final values = _values[name.toLowerCase()];
    return values == null ? null : List<String>.from(values);
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values.single;
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    final additions = value is Iterable
        ? value.map((item) => item.toString())
        : <String>[value.toString()];
    _values.putIfAbsent(key, () => <String>[]).addAll(additions);
    if (key == HttpHeaders.contentTypeHeader) {
      _contentType = ContentType.parse(_values[key]!.last);
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    final values = value is Iterable
        ? value.map((item) => item.toString()).toList()
        : <String>[value.toString()];
    _values[key] = values;
    if (key == HttpHeaders.contentTypeHeader) {
      _contentType = ContentType.parse(values.single);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpHeaders call: $invocation');
}
