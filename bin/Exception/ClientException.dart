class ClientException implements Exception{
  String message;

  ClientException([this.message = 'Connection with client failed']);

  @override
  String toString() => message;
}