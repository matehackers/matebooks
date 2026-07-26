/// Turso database configuration.
/// Values are read from --dart-define at compile time.
/// Pass them when running or building:
///   flutter run --dart-define=TURSO_DB_URL=... --dart-define=TURSO_AUTH_TOKEN=...
/// Or create a .env file and use --dart-define-from-file=.env.
class TursoConfig {
  /// Your Turso database HTTP URL.
  /// Set via --dart-define=TURSO_DB_URL=<url>
  static const String databaseUrl = String.fromEnvironment(
    'TURSO_DB_URL',
    defaultValue: '',
  );

  /// Your Turso database auth token.
  /// Set via --dart-define=TURSO_AUTH_TOKEN=<token>
  static const String authToken = String.fromEnvironment(
    'TURSO_AUTH_TOKEN',
    defaultValue: '',
  );

  /// Your Google Books API key.
  /// Set via --dart-define=GOOGLE_BOOKS_API_KEY=<key>
  /// Get one at: https://console.cloud.google.com/apis/credentials
  static const String googleBooksApiKey = String.fromEnvironment(
    'GOOGLE_BOOKS_API_KEY',
    defaultValue: '',
  );
}
