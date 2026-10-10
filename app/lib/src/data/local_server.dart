import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';

/// Sixora without a server: the server's own code runs inside the app, with
/// its database in the app's data folder. Requests go to it directly, not
/// over the network.
///
/// Everything else stays as with a server: the same encryption, the same
/// sync and recycle bin. The database holds only ciphertext, like on a
/// server. Later the accounts can move to a real server
/// (`AppController.moveToServer`).
class LocalServer {
  LocalServer._(this._dir, this._app);

  /// Stands in for the server address; never resolved on the network.
  static final uri = Uri.parse('local://this-device/');

  /// The one account of the local database.
  static const username = 'local';

  static bool isLocal(Uri server) => server.scheme == uri.scheme;

  /// Where the database lives; set when the app starts.
  static late Directory folder;

  static LocalServer? _current;

  final Directory _dir;
  final SixoraServerApp _app;

  static File get _file => File(p.join(folder.path, 'sixora.db'));

  /// Whether a local database exists, e.g. left from an earlier start.
  static bool get exists => _file.existsSync();

  /// Opens the database (creating it if needed).
  static LocalServer open() {
    final current = _current;
    if (current != null && current._dir.path == folder.path) return current;
    current?.close();
    folder.createSync(recursive: true);
    final app = SixoraServerApp(
      db: openSixoraDatabase(_file.path),
      registration: Registration.open,
    )..startMaintenance();
    return _current = LocalServer._(folder, app);
  }

  /// An API client that talks to the local server.
  static SixoraApi api({String? token}) =>
      SixoraApi(uri, token: token, client: _InProcessClient(open()._app));

  void close() {
    _app.close();
    _app.db.close();
    if (identical(_current, this)) _current = null;
  }

  /// Closes and deletes the database: after a move to a server, or when the
  /// user starts over.
  static void delete() {
    _current?.close();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${_file.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
  }
}

/// Hands requests to the server's handler in the same process.
class _InProcessClient extends http.BaseClient {
  _InProcessClient(this._app);
  final SixoraServerApp _app;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final url = request.url;
    final response = await _app.handler(
      shelf.Request(
        request.method,
        Uri(
          scheme: 'http',
          host: 'localhost',
          path: url.path,
          query: url.hasQuery ? url.query : null,
        ),
        headers: request.headers,
        body: body,
      ),
    );
    return http.StreamedResponse(
      response.read(),
      response.statusCode,
      contentLength: response.contentLength,
      headers: response.headers,
      request: request,
    );
  }
}
