class HelloWordException implements Exception{
  final String _message;

  HelloWordException([this._message = '']);

  @override
  String toString() => 'Wrong hello word $_message';
}