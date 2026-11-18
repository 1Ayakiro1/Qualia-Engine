import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import '../privacy/privacy_preferences.dart';
import '../privacy/privacy_http_client.dart';

/// Supabase Auth bootstrap and GitHub OAuth actions.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  bool _initialized = false;

  bool get isInitialized => _initialized && Supabase.instance.isInitialized;

  Future<void> initialize() async {
    PrivacyPreferences.instance.requireExternalConsent();
    if (_initialized) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      httpClient: PrivacyHttpClient(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
      ),
    );
    _initialized = true;
  }

  User? get currentUser =>
      isInitialized ? Supabase.instance.client.auth.currentUser : null;

  Stream<User?> get userChanges async* {
    if (!isInitialized) {
      yield null;
      return;
    }
    final client = Supabase.instance.client.auth;
    yield client.currentUser;
    yield* client.onAuthStateChange.map((event) => event.session?.user);
  }

  Future<void> signInWithGitHub() async {
    PrivacyPreferences.instance.requireExternalConsent();
    if (!isInitialized) {
      throw StateError('Supabase Auth is not initialized.');
    }
    await PrivacyHttpClient.auditBrowserLaunch(Uri.parse(SupabaseConfig.url));
    PrivacyPreferences.instance.requireExternalConsent();
    final launched = await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: SupabaseConfig.oauthRedirect,
    );
    if (!launched) {
      throw StateError('Could not open the GitHub sign-in page.');
    }
  }

  Future<void> signOut() async {
    if (!isInitialized) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } on StateError {
      // The privacy client may block the remote revocation after consent was
      // withdrawn. Supabase clears the local session before that request, so
      // the local sign-out is still complete and no data leaves the process.
    }
  }

  Future<void> handleOAuthCallback(Uri uri) async {
    if (!isInitialized) return;
    PrivacyPreferences.instance.requireExternalConsent();
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService.instance,
);

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges;
});
