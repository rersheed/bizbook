/// Supabase wiring for BizBook.
///
/// Override at build/run time if needed:
///   --dart-define=SUPABASE_URL=...
///   --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ixjfpizmrsqebfqebsvx.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4amZwaXptcnNxZWJmcWVic3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA4OTMwMTUsImV4cCI6MjEwNjQ2OTAxNX0.2s1dzs37BiClDtqOcsFWTkMxz_SgtI_wdDBD5VQNIzA',
  );

  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR_') &&
      anonKey != 'YOUR_ANON_KEY';
}
