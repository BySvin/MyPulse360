import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Mock-backend password storage: a random per-user salt plus a salted
/// SHA-256 hash, never the plaintext password. Session-lifetime only, like
/// the rest of [MockDatabase] — not real at-rest security (there's no real
/// server here), but it makes login actually verify a credential instead of
/// trusting the email alone.
class CredentialsStore {
  final Map<String, _Credential> _byUserId = {};

  void setPassword(String userId, String password) {
    final salt = _generateSalt();
    _byUserId[userId] = _Credential(salt: salt, hash: _hash(password, salt));
  }

  bool verify(String userId, String password) {
    final credential = _byUserId[userId];
    if (credential == null) return false;
    return credential.hash == _hash(password, credential.salt);
  }

  bool hasPassword(String userId) => _byUserId.containsKey(userId);

  void remove(String userId) => _byUserId.remove(userId);

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();
}

class _Credential {
  const _Credential({required this.salt, required this.hash});

  final String salt;
  final String hash;
}
