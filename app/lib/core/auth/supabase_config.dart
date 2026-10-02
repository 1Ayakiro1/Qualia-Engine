/// Public Supabase client configuration for the desktop application.
///
/// Override with `--dart-define` in release builds if deploying another
/// Supabase project. Only the publishable key belongs in a desktop client.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://egqzeqlenafpnziplxgb.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ImX_7FQU2jvtEBnCjFdoYg_8UkuW5kr',
  );
  static const String oauthRedirect = String.fromEnvironment(
    'SUPABASE_OAUTH_REDIRECT',
    defaultValue: 'qualia-engine://auth/callback',
  );
}
