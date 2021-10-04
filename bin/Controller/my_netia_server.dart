import 'dart:io';

import '../Network/Server.dart';

void main(List<String> args) {
  const patternArgs = 'Arguments must have this syntax :\nipServer portServer ipDatabase portDatabase\nip format: 127.0.0.1\nport format: a number between 0-65535';
  if(args.length != 4 || !isArgsValid(args)){
    print(patternArgs);
    exit(0);
  }
  var server = Server(args[0], int.parse(args[1]), args[2], int.parse(args[3]));
  server.start();
}

bool isArgsValid(List<String> args){
  var ipv4Reg = RegExp(r'^(?!0)(?!.*\.$)((1?\d?\d|25[0-5]|2[0-4]\d)(\.|$)){4}$', caseSensitive: false, multiLine: false);
  return ipv4Reg.hasMatch(args[0]) && isNumeric(args[1]) && ipv4Reg.hasMatch(args[2]) && isNumeric(args[3]);
}

bool isNumeric(String text){
  try{
    var port = int.parse(text);
    if(port > 0 && port < 65535){
      return true;
    }
    return false;
  } catch(e){ return false; }
}
