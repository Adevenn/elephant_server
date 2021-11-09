import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

import '../Exception/client_exception.dart';
import '../Exception/encryption_exception.dart';
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
    _socket.timeout(Duration(seconds: 5));
    _queue = StreamQueue(_socket);
  }

  ///Receive databaseName, username and password
  Future<Database> _dbValues() async{
    try{
      var dbValues = jsonDecode(await readSym());
      await synchronizeWrite();
      return Database(_ipDatabase, _portDatabase, dbValues['database'], dbValues['username'], dbValues['password']);
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)_dbValues: Connection lost with ${_socket.address}\n$e'); }
    catch(e){ throw Exception(e); }
  }

  Future<Database> init() async{
    try{
      _socket.write(_asym.publicKey);

      //Key Exchange
      _sym = SymEncryption(await readAsym());
      await synchronizeWrite();

      return await _dbValues();
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)init: Connection lost with ${_socket.address}\n$e'); }
    on EncryptionException catch(e){ throw ClientException('(CustomSocket)init:\n$e'); }
    catch(e){ throw Exception('(CustomSocket)init: Connection lost with host\n$e'); }
  }

  Future<Database> setup() async{
    try{
      await synchronizeWrite();

      //Key Exchange
      _sym = SymEncryption(await readAsym());
      await synchronizeWrite();

      return await _dbValues();
    }
    on SocketException catch(e){ throw SocketException('(CustomSocket)setup: Connection lost with ${_socket.address}\n$e'); }
    on EncryptionException catch(e){ throw EncryptionException('(SocketCustom)setup:\n$e'); }
    catch(e){ throw Exception('(CustomSocket)setup: Connection lost with host\n$e'); }
  }

  ///Disconnect the [_socket] and return an Exception if an error occurs
  Future<void> disconnect() async{
    try {
      await _socket.flush();
      await _socket.close();
    }
    on SocketException catch(e){ print('(SocketCustom)disconnect:\n$e'); }
    catch(e) { throw Exception(e); }
    finally{ _socket.destroy(); }
  }

  Future<void> writeBigString(String file) async{
    try{
      await writeSym(file);
      await write('--- end of file ---');
    } catch(e){ throw Exception(e); }
  }

  Future<String> readBigString() async{
    try{
      var file = '';
      while(true){
        file += String.fromCharCodes(await _queue.next);
        if(file.endsWith('--- end of file ---')) {
          break;
        }
      }
      return _sym.decryptString(file.substring(0, file.length - 19));
    } catch(e){ throw Exception(e); }
  }

  Future<void> write(String plainText) async{
    try{ _socket.write(plainText); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)write\n$e'); }
    catch (e){ throw Exception('(CustomSocket)write:\n$e'); }
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
    on EncryptionException catch(e){ throw EncryptionException('(CustomSocket)read:\n$e'); }
    catch(e) { throw Exception('(CustomSocket)read:\n$e'); }
  }

  Future<String> readAsym() async{
    try{ return _asym.decrypt(await _queue.next); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)readAsym\n$e'); }
    on EncryptionException catch(e){ throw EncryptionException('(CustomSocket)readAsym:\n$e'); }
    catch(e) { throw Exception('(CustomSocket)readAsym:\n$e'); }
  }

  Future<String> readSym() async{
    try{ return _sym.decrypt(await _queue.next); }
    on SocketException catch(e){ throw SocketException('(CustomSocket)readSym:\n$e'); }
    on EncryptionException catch(e){ throw EncryptionException('(CustomSocket)readSym:\n$e'); }
    catch(e) { throw Exception('(CustomSocket)readSym:\n$e'); }
  }

  Future<void> synchronizeRead() async{
    try{ await _queue.next; }
    on SocketException catch(e){ throw SocketException('(CustomSocket)synchronizeRead:\n$e'); }
    catch (e){ throw Exception('(CustomSocket)synchronizeRead:\n$e'); }
  }
}