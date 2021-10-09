import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../Exception/hello_word_exception.dart';
import '../Model/cell.dart';
import '../Model/Elements/checkbox.dart';
import '../Model/Elements/element.dart';
import '../Model/Elements/images.dart';
import '../Model/Elements/texts.dart';
import '../Model/sheet.dart';
import 'socket_custom.dart';
import 'database.dart';


class Server{
  final String _ipServer;
  final int _portServer;
  final String _ipDatabase;
  final int _portDatabase;


  Server(this._ipServer, this._portServer, this._ipDatabase, this._portDatabase);

  void start() async{
    var server = await ServerSocket.bind(_ipServer, _portServer);
    try{
      print('/* Waiting for connections */');
      server.listen(_handleClient);
    } catch(e) { await server.close(); }
  }

  void _handleClient(Socket _socket) async{
    print('/* New client connection */');
    var socket = SocketCustom(_socket, _ipDatabase, _portDatabase);
    try{
      var database = await socket.setup();
      await _handleRequest(socket, database);
    }
    on HelloWordException catch(e){ print(e); }
    on SocketException catch(e){ print('(Server)_handleClient :\n${e.toString()}'); }
    catch(e){ print('(Server)_handleClient:\n$e'); }
    await socket.disconnect();
    print('Client disconnected');
  }

  Future<void> _handleRequest(SocketCustom socket, Database database) async{
    try{
      var request = await socket.readAsym();
      await socket.synchronizeWrite();
      print('Request : $request');

      switch(request){
        case 'testConnection':
          await _testConnection(socket, database);
          break;
        case 'cells':
          await _cells(socket, database);
          break;
        case 'cellContent':
          await _cellContent(socket, database);
          break;
        case 'sheetContent':
          await _sheetContent(socket, database);
          break;
        case 'addCell':
          await _addCell(socket, database);
          break;
        case 'addObject':
          await _addObject(socket, database);
          break;
        case 'deleteObject':
          await _deleteObject(socket, database);
          break;
        case 'updateObject':
          await _updateObject(socket, database);
          break;
        default:
          print('No server request match with client request');
          break;
      }
    }
    on DatabaseException catch(e){ print('(Server)_handleRequest:\n$e'); }
    on DatabaseTimeoutException catch(e){ print('(Server)_handleRequest:\n$e'); }
    on SocketException catch(e){ throw SocketException('(Server)_handleRequest:\n$e'); }
    catch(e) { throw Exception('(Server)_handleRequest:\n$e'); }
  }

  ///Try to connect to [database]
  Future<void> _testConnection(SocketCustom socket, Database database) async{
    try{
      await database.testConnection();
      await socket.writeAsym('success');
      print('success');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('databaseTimeout');
      print('(Server)_testConnection:\n${e.toString()}');
    }
    on SocketException{ print('(Server)_testConnection: Connection lost with '); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_testConnection:\n$e');
    }
  }

  ///Get cells from [database] and send it to client with [socket]
  ///
  /// Each cell is convert to json and encrypted
  Future<void> _cells(SocketCustom socket, Database database) async {
    try{
      var matchWord = await socket.readAsym();
      var cells = await database.selectCells(matchWord);
      await socket.writeSym(listToJson(cells));
    }
    on SocketException{ print('(Server)_cells: Client disconnected'); }
    on DatabaseException catch(e) { print('(Server)_cells:\n${e.toString()}'); }
    on DatabaseTimeoutException catch(e) { print('(Server)_cells:\n${e.toString()}'); }
    catch(e) { throw Exception('(Server)_cells:\n$e'); }
  }

  ///Get the cell content from [database]
  Future<void> _cellContent(SocketCustom socket, Database database) async {
    try{
      var idCell = int.parse(await socket.readAsym());
      var sheets = await database.selectCellContent(idCell);
      await socket.writeSym(listToJson(sheets));
    }
    on SocketException{ print('SocketException'); }
    on DatabaseException catch(e) { print('(Server)_testConnection:\n${e.toString()}'); }
    on DatabaseTimeoutException catch(e) { print('(Server)_testConnection:\n${e.toString()}'); }
    catch (e){ print('Connection lost with host during cellContent'); }
  }

  ///Get the sheet content from [database]
  Future<void> _sheetContent(SocketCustom socket, Database database) async{
    try{
      var idSheet = int.parse(await socket.readAsym());
      var elements = await database.selectSheetContent(idSheet);
      await socket.writeSym(listToJson(elements));
    }
    on SocketException{ print('SocketException'); }
    on DatabaseException catch(e) { print('(Server)_testConnection:\n${e.toString()}'); }
    on DatabaseTimeoutException catch(e) { print('(Server)_testConnection:\n${e.toString()}'); }
    catch (e){ print(e); }
  }

  ///Receive a json containing a Cell
  ///Call [database] to add this Cell
  Future<void> _addCell(SocketCustom socket, Database database) async{
    try{
      var jsonObj = jsonDecode(await socket.readSym());
      var cell = Cell.fromJson(jsonObj);
      database.addCell(cell.title, cell.subtitle, cell.type);
      await socket.writeAsym('success');
      print('success');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addCell:\n${e.toString()}');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addCell:\n${e.toString()}');
    }
    on SocketException{ print('(Server)_addCell: Connection lost with '); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addCell:\n$e');
    }
  }

  ///Receive a type and a json
  ///Call the [database] to add the jsonObject
  Future<void> _addObject(SocketCustom socket, Database database) async{
    try{
      var type = await socket.readAsym();
      print('type: $type');
      await socket.synchronizeWrite();
      var json = jsonDecode(await socket.readSym());

      switch(type){
        case 'Sheet':
          var sheet = Sheet.fromJson(jsonDecode(json));
          database.addSheet(sheet.idParent, sheet.title, sheet.subtitle, sheet.idOrder);
          break;
        case 'Element':
          var element = Element.fromJson(jsonDecode(json));
          switch(element.runtimeType.toString()){
            case 'CheckBox':
              database.addCheckBox((element as CheckBox).text, element.isChecked, element.idParent, element.idOrder);
              break;
            case 'Images':
              database.addImage((element as Images).data, element.idParent, element.idOrder);
              break;
            case 'Texts':
              database.addTexts((element as Texts).text, element.txtType.index, element.idParent, element.idOrder);
              break;
            default:
              throw Exception('Incorrect element type');
          }
      }
      await socket.writeAsym('success');
      print('success');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addObject:\n${e.toString()}');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addObject:\n${e.toString()}');
    }
    on SocketException{ print('(Server)_addObject: Connection lost with '); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addObject:\n$e');
    }
  }

  ///Receive a type and an index
  ///Call the [database] to delete the matching object
  Future<void> _deleteObject(SocketCustom socket, Database database) async{
    try{
      var type = await socket.readAsym();
      await socket.synchronizeWrite();
      var index = int.parse(await socket.readAsym());
      switch(type){
        case 'Cell':
          database.deleteCell(index);
          break;
        case 'Sheet':
          database.deleteSheet(index);
          break;
        case 'CheckBox':
          database.deleteCheckBox(index);
          break;
        case 'Images':
          database.deleteImage(index);
          break;
        case 'Texts':
          database.deleteTexts(index);
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeAsym('success');
      print('success');
    }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_deleteObject:\n$e');
    }
  }

  ///Receive a type and a json
  ///Call [database] to update the jsonObject
  Future<void> _updateObject(SocketCustom socket, Database database) async{
    try{
      var type = await socket.readAsym();
      await socket.synchronizeWrite();
      var json = jsonDecode(await socket.readSym());
      print('json: $json');
      switch(type){
        case 'Cell':
          var cell = Cell.fromJson(json);
          database.updateCell(cell.id, cell.title, cell.subtitle);
          break;
        case 'Sheet':
          var sheet = Sheet.fromJson(json);
          database.updateSheet(sheet.id, sheet.title, sheet.subtitle, sheet.idOrder);
          break;
        case 'Element':
          var elem = Element.fromJson(json);
          switch(elem.runtimeType.toString()){
            case 'CheckBox':
              database.updateCheckBox((elem as CheckBox).id, elem.isChecked, elem.text, elem.idOrder);
              break;
            case 'Images':
              database.updateImage((elem as Images).id, elem.data, elem.idOrder);
              break;
            case 'Texts':
              database.updateTexts((elem as Texts).id, elem.text, elem.txtType.index, elem.idOrder);
              break;
            default:
              throw Exception('Incorrect element type');
          }
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeAsym('success');
      print('success');
    } catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
  }

  ///Convert a [list] of objects to a json
  ///To extract the json must be jsonDecode to get a list of json
  ///and each item in the list must be jsonDecode to recreate the object
  String listToJson(var list){
    var json = <String>[];
    //print('List :');
    for(var i = 0; i < list.length; i++){
      //print(list[i].toJson());
      json.add(jsonEncode(list[i]));
    }
    return jsonEncode(json);
  }
}