import 'dart:io';

import 'package:async/async.dart';

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
    var databaseName = await readAsym();
    await synchronizeWrite();
    var username = await readAsym();
    await synchronizeWrite();
    var password = await readAsym();
    await synchronizeWrite();

    return Database(_ipDatabase, _portDatabase, databaseName, username, password);
  }

  Future<Database> init() async{
    try{
      _socket.write(_asym.publicKey);
      return await _dbValues();
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)_init: Connection lost with ${_socket.address}\n${e.toString()}'); }
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
    catch(e){ throw Exception('(CustomSocket)_setup: Connection lost with host\n$e'); }
  }

  ///Disconnect the [_socket] and return an Exception if an error occurs
  Future<void> disconnect() async{
    try {
      await _socket.flush();
      await _socket.close();
      _socket.destroy();
    }
    on SocketException { throw SocketException; }
    catch(e) { throw Exception(e); }
  }

  Future<void> write(String plainText) async{
    try{ _socket.write(plainText); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)write\n$e'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeWrite:\n$e'); }
  }

  Future<void> writeAsym(String plainText) async{
    try{ _socket.write(_asym.encrypt(plainText)); }
    on SocketException { throw SocketException('(CustomSocket)writeAsym'); }
    catch(e){ throw Exception('(CustomSocket)writeAsym:\n$e'); }
  }

  Future<void> writeSym(String plainText) async{
    try{ _socket.write(_sym.encrypt(plainText)); }
    on SocketException { throw SocketException('(CustomSocket)writeSym'); }
    catch(e){ throw Exception('(CustomSocket)writeSym:\n$e'); }
  }

  Future<void> synchronizeWrite() async{
    try{ _socket.write('ok'); }
    on SocketException { throw SocketException('(CustomSocket)synchronizeWrite'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeWrite:\n$e'); }
  }

  Future<String> read() async{
    try{ return String.fromCharCodes(await _queue.next); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)read\n$e'); }
    catch(e) { throw Exception('(CustomSocket)readAsym;\n$e'); }
  }

  Future<String> readAsym() async{
    try{ return _asym.decrypt(await _queue.next); }
    on SocketException { throw SocketException('(CustomSocket)readAsym'); }
    catch(e) { throw Exception('(CustomSocket)readAsym;\n$e'); }
  }

  Future<String> readSym() async{
    try{ return _sym.decrypt(await _queue.next); }
    on SocketException { throw SocketException('(CustomSocket)readSym'); }
    catch(e) { throw Exception('(CustomSocket)readSym;\n$e'); }
  }

  Future<void> synchronizeRead() async{
    try{ await _queue.next; }
    on SocketException { throw SocketException('(CustomSocket)synchronizeRead'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeRead:\n$e'); }
  }
}