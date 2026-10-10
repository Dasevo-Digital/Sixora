import '../api/api_client.dart';

/// The browser reports every network problem as `ClientException`.
ApiException? transportError(Object error, Uri uri) => null;
