/// In the browser there are no isolates: [work] runs right away (Argon2id
/// takes a fraction of a second there as WebAssembly).
Future<T> runInBackground<T>(T Function() work) async => work();
