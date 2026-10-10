import 'dart:isolate';

/// Runs [work] in a background isolate, so the UI keeps running.
Future<T> runInBackground<T>(T Function() work) => Isolate.run(work);
