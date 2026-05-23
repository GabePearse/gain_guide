import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/external_auth_profile.dart';

class ExternalAuthService {
  ExternalAuthService._internal();

  static final ExternalAuthService instance = ExternalAuthService._internal();

  Future<ExternalAuthProfile> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();

    if (!googleSignIn.supportsAuthenticate()) {
      throw StateError('Google sign-in is not available on this platform.');
    }

    final account = await googleSignIn.authenticate();
    final displayName = account.displayName ?? account.email.split('@').first;

    return ExternalAuthProfile(
      provider: 'google',
      displayName: displayName,
      email: account.email,
    );
  }

  Future<ExternalAuthProfile> signInWithApple() async {
    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw StateError('Sign in with Apple is not available on this device.');
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final email = credential.email ??
        '${credential.userIdentifier ?? 'apple-user'}@privaterelay.appleid.com';
    final displayName = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

    return ExternalAuthProfile(
      provider: 'apple',
      displayName: displayName.isEmpty ? email.split('@').first : displayName,
      email: email,
    );
  }
}
