import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

import '../Exception/client_exception.dart';
import 'database.dart';
import 'Encryption/asym_encryption.dart';
import 'Encryption/sym_encryption.dart';

class SocketCustom{

  final Socket _socket;
  final AsymEncryption _asym;
  late final SymEncryption _sym;
  late final StreamQueue _queue;

  final String _ipDatabase;
  final int _portDatabase;

  SocketCustom(this._socket, this._asym, this._ipDatabase, this._portDatabase){
    _queue = StreamQueue(_socket);
  }

  ///Receive databaseName, username and password
  Future<Database> _dbValues() async{
    try{
      var dbValues = jsonDecode(await readAsym());
      await synchronizeWrite();
      return Database(_ipDatabase, _portDatabase, dbValues['database'], dbValues['username'], dbValues['password']);
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)_init: Connection lost with ${_socket.address}\n${e.toString()}'); }
    catch(e){ throw Exception(e); }
  }

  Future<Database> init() async{
    try{
      _socket.write(_asym.publicKey);
      return await _dbValues();
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)_init: Connection lost with ${_socket.address}\n${e.toString()}'); }
    on ArgumentError catch(e){ throw ClientException('(CustomSocket)init:\n$e'); }
    catch(e){ throw Exception('(CustomSocket)_init: Connection lost with host\n$e'); }
  }

  Future<Database> setup() async{
    try{
      await synchronizeWrite();
      var symKey = await readAsym();
      _sym = SymEncryption(symKey);
      await synchronizeWrite();
      _asym.clientKey = await readSym();
      await synchronizeWrite();
      return await _dbValues();
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)_setup: Connection lost with ${_socket.address}\n${e.toString()}'); }
    on ArgumentError catch(e){ throw ClientException('(SocketCustom)setup:\n$e'); }
    catch(e){ throw Exception('(CustomSocket)_setup: Connection lost with host\n$e'); }
  }

  ///Disconnect the [_socket] and return an Exception if an error occurs
  Future<void> disconnect() async{
    try {
      await _socket.flush();
      await _socket.close();
      _socket.destroy();
    }
    on SocketException catch(e){ throw SocketException('(SocketCustom)disconnect:\n$e'); }
    catch(e) { throw Exception(e); }
  }

  Future<void> write(String plainText) async{
    try{ _socket.write(plainText); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)write\n$e'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeWrite:\n$e'); }
  }

  Future<void> writeAsym(String plainText) async{
    try{ _socket.write(_asym.encrypt(plainText)); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)writeAsym:\n$e'); }
    catch(e){ throw Exception('(CustomSocket)writeAsym:\n$e'); }
  }

  Future<void> writeSym(String plainText) async{
    try{ _socket.write(_sym.encrypt(plainText)); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)writeSym:\n$e'); }
    catch(e){ throw Exception('(CustomSocket)writeSym:\n$e'); }
  }

  Future<void> synchronizeWrite() async{
    try{ _socket.write('ok'); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)synchronizeWrite:\n$e'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeWrite:\n$e'); }
  }

  Future<String> read() async{
    try{ return String.fromCharCodes(await _queue.next); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)read\n$e'); }
    on ArgumentError catch(e){ throw ClientException('(CustomSocket)readSym;\n$e'); }
    catch(e) { throw Exception('(CustomSocket)readAsym;\n$e'); }
  }

  Future<String> readAsym() async{
    try{ return _asym.decrypt(await _queue.next); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)readAsym\n$e'); }
    on ArgumentError catch(e){ throw ClientException('(CustomSocket)readSym;\n$e'); }
    catch(e) { throw Exception('(CustomSocket)readAsym;\n$e'); }
  }

  Future<String> readSym() async{
    try{ return _sym.decrypt(await _queue.next); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)readSym:\n$e'); }
    on ArgumentError catch(e){ throw ClientException('(CustomSocket)readSym;\n$e'); }
    catch(e) { throw Exception('(CustomSocket)readSym;\n$e'); }
  }

  Future<void> synchronizeRead() async{
    try{ await _queue.next; }
    on SocketException catch(e){ throw SocketException('(CustomSocket)synchronizeRead:\n$e'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeRead:\n$e'); }
  }
}