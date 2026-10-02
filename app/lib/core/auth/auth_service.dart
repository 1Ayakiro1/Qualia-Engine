import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Supabase Auth bootstrap and GitHub OAuth actions.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  bool _initialized = false;

  bool get isInitialized => _initialized && Supabase.instance.isInitialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
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
    if (!isInitialized) {
      throw StateError('Supabase Auth is not initialized.');
    }
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
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> handleOAuthCallback(Uri uri) async {
    if (!isInitialized) return;
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService.instance,
);

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges;
});
