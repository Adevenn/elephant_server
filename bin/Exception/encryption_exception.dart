class EncryptionException implements Exception{
  String message;

  EncryptionException([this.message = 'Encryption failed']);

  @override
  String toString() => message;
}