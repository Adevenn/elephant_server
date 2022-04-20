import 'dart:io';

import '../Network/server.dart';

void main(List<String> args) {
  const patternArgs = '''Arguments must have this syntax :
  authDB_username authDB_password dataDB_username dataDB_password''';
  if (args.length != 4) {
    print(patternArgs);
    exit(0);
  }
  var server = Server(args[0], args[1], args[2], args[3]);
  server.start();
}
