/// Build environment. Development and test builds use their own keystore
/// entry and data folder, so they never touch the data of the real app:
/// `--dart-define=SIXORA_ENV=dev` (or `test` for the integration tests).
abstract final class AppEnv {
  static const name = String.fromEnvironment(
    'SIXORA_ENV',
    defaultValue: 'prod',
  );
  static const isDev = name != 'prod';

  static const secretsEntry = isDev ? 'sixora.$name.secrets' : 'sixora.secrets';
  static const dataFolder = name;
}
