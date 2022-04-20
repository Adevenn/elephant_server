import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class Hash {
  static Map<String, String> hashString(String password) {
    var salt = _createSalt();
    var bytes = utf8.encode(password + salt);
    var digest = sha256.convert(bytes);
    return {'hash_pwd' : digest.toString(), 'salt' : salt};
  }

  static String hashWithSalt(String saltedPwd) {
    var bytes = utf8.encode(saltedPwd);
    return sha256.convert(bytes).toString();
  }

  static String _createSalt() {
    var random = Random.secure();
    var salt = '';
    for (var i = 0; i < 8; i++) {
      salt += String.fromCharCode(random.nextInt(74) + 48);
    }
    return salt;
  }
}
