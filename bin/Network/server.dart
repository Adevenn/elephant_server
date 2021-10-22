import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../Exception/encryption_exception.dart';
import '../Model/cell.dart';
import '../Model/Elements/checkbox.dart';
import '../Model/Elements/element.dart';
import '../Model/Elements/images.dart';
import '../Model/Elements/texts.dart';
import '../Model/sheet.dart';
import 'Encryption/asym_encryption.dart';
import 'socket_custom.dart';
import 'database.dart';

class Server{
  final String _ipServer;
  final int _portServer;
  final AsymEncryption _asym = AsymEncryption();
  final String _ipDatabase;
  final int _portDatabase;


  Server(this._ipServer, this._portServer, this._ipDatabase, this._portDatabase);

  void start() async{
    var server = await ServerSocket.bind(_ipServer, _portServer);
    try{
      print('/* Waiting for connections */');
      server.listen(_handleClient);
    } catch(e){ await server.close(); }
  }

  void _handleClient(Socket _socket) async{
    print('/* New client connection */');
    var socket = SocketCustom(_socket, _asym, _ipDatabase, _portDatabase);
    try{
      var request = await socket.read();
      print('Request: $request');
      switch(request){
        case 'init':
          await _init(socket);
          break;
        case 'cells':
          await _cells(socket);
          break;
        case 'sheets':
          await _sheets(socket);
          break;
        case 'elements':
          await _elements(socket);
          break;
        case 'addCell':
          await _addCell(socket);
          break;
        case 'addItem':
          await _addItem(socket);
          break;
        case 'deleteItem':
          await _deleteItem(socket);
          break;
        case 'updateItem':
          await _updateItem(socket);
          break;
        case 'updateOrder':
          await _updateOrder(socket);
          break;
        default:
          print('No server request match with client request');
          break;
      }
    }
    catch(e){ print('(Server)_handleClient:\n$e'); }
    await socket.disconnect();
    print('Client disconnected');
  }

  ///Try to connect to database
  Future<void> _init(SocketCustom socket) async{
    try{
      var database = await socket.init();
      await database.testConnection();
      await socket.write('success');
    }
    on DatabaseTimeoutException catch(e){
      await socket.write('databaseTimeout');
      print('(Server)_init:\n$e');
    }
    on SocketException{ print('(Server)_init: Connection lost with '); }
    catch(e){
      await socket.write('failed');
      print('(Server)_init:\n$e');
    }
  }

  ///Get cells from database and send it to client with [socket]
  ///
  /// Each cell is convert to json and encrypted
  Future<void> _cells(SocketCustom socket) async {
    try{
      var database = await socket.setup();
      var matchWord = await socket.readAsym();
      var cells = await database.selectCells(matchWord);
      await socket.writeSym(listToJson(cells));
    }
    on SocketException{ print('(Server)_cells: Client disconnected'); }
    on EncryptionException{ print('(Server)_cells:\nEncryption Exception'); }
    on DatabaseException catch(e) { print('(Server)_cells:\n$e'); }
    on DatabaseTimeoutException catch(e) { print('(Server)_cells:\n$e'); }
    catch(e){ throw Exception('(Server)_cells:\n$e'); }
  }

  ///Get the cell content from database
  Future<void> _sheets(SocketCustom socket) async {
    try{
      var database = await socket.setup();
      var idCell = int.parse(await socket.readAsym());
      var sheets = await database.selectSheets(idCell);
      await socket.writeSym(listToJson(sheets));
    }
    on SocketException{ print('(Server)_cellContent:\nSocketException'); }
    on EncryptionException{ print('(Server)_cellContent:\nEncryption Exception'); }
    on DatabaseException catch(e) { print('(Server)_cellContent:\n$e'); }
    on DatabaseTimeoutException catch(e) { print('(Server)_cellContent:\n$e'); }
    catch(e){ print('Connection lost with host during cellContent\n$e'); }
  }

  ///Get the sheet content from database
  Future<void> _elements(SocketCustom socket) async{
    try{
      var database = await socket.setup();
      var idSheet = int.parse(await socket.readAsym());
      var elements = await database.selectElements(idSheet);
      await socket.writeSym(listToJson(elements));
    }
    on SocketException{ print('(Server)_sheetContent:\nSocketException'); }
    on EncryptionException{ print('(Server)_sheetContent:\nEncryption Exception'); }
    on DatabaseException catch(e) { print('(Server)_sheetContent:\n$e'); }
    on DatabaseTimeoutException catch(e) { print('(Server)_sheetContent:\n$e'); }
    catch(e){ print('(Server)_sheetContent:\n$e'); }
  }

  ///Receive a json containing a Cell
  ///Call database to add this Cell
  Future<void> _addCell(SocketCustom socket) async{
    try{
      var database = await socket.setup();
      var jsonObj = jsonDecode(await socket.readSym());
      var cell = Cell.fromJson(jsonObj);
      database.addCell(cell.title, cell.subtitle, cell.type);
      await socket.writeAsym('success');
      print('success');
    }
    on EncryptionException{
      await socket.writeAsym('failed');
      print('(Server)_addCell\nEncryption Exception');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addCell:\n$e');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addCell:\n$e');
    }
    on SocketException catch(e){ print('(Server)_addCell: Connection lost with ${e.address}'); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addCell:\n$e');
    }
  }

  ///Receive a type and a json
  ///Call the database to add the jsonObject
  Future<void> _addItem(SocketCustom socket) async{
    try{
      var database = await socket.setup();
      var type = await socket.readAsym();
      await socket.synchronizeWrite();
      var json = jsonDecode(await socket.readSym());
      switch(type){
        case 'Sheet':
          var sheet = Sheet.fromJson(jsonDecode(json));
          database.addSheet(sheet.idParent, sheet.title, sheet.subtitle, sheet.idOrder);
          break;
        case 'CheckBox':
          var element = Element.fromJson(jsonDecode(json));
          database.addCheckBox((element as CheckBox).text, element.isChecked, element.idParent, element.idOrder);
          break;
        case 'Images':
          var element = Element.fromJson(jsonDecode(json));
          database.addImage((element as Images).data, element.idParent, element.idOrder);
          break;
        case 'Texts':
          var element = Element.fromJson(jsonDecode(json));
          database.addTexts((element as Texts).text, element.txtType.index, element.idParent, element.idOrder);
          break;
        default:
          throw Exception('(Server)_addObject: Wrong type -> $type');
      }
      await socket.writeAsym('success');
      print('success');
    }
    on EncryptionException{
      await socket.writeAsym('failed');
      print('(Server)_addObject:\nEncryption Exception');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addObject:\n$e');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addObject:\n$e');
    }
    on SocketException catch(e){ print('(Server)_addObject: Connection lost with ${e.address}'); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_addObject:\n$e');
    }
  }

  ///Receive a type and an index
  ///Call the database to delete the matching object
  Future<void> _deleteItem(SocketCustom socket) async{
    try{
      var database = await socket.setup();
      var type = await socket.readAsym();
      await socket.synchronizeWrite();
      var idItem = int.parse(await socket.readAsym());
      print('idItem: $idItem');
      switch(type){
        case 'Cell':
          database.deleteCell(idItem);
          break;
        case 'Sheet':
          database.deleteSheet(idItem);
          break;
        case 'CheckBox':
          database.deleteCheckBox(idItem);
          break;
        case 'Images':
          database.deleteImage(idItem);
          break;
        case 'Texts':
          database.deleteTexts(idItem);
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeAsym('success');
      print('success');
    }
    on EncryptionException{
      await socket.writeAsym('failed');
      print('(Server)_deleteObject:\nEncryption Exception');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_deleteObject:\n$e');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_deleteObject:\n$e');
    }
    on SocketException catch(e){ print('(Server)_deleteObject: Connection lost with ${e.address}'); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_deleteObject:\n$e');
    }
  }

  ///Receive a type and a json
  ///Call database to update the jsonObject
  Future<void> _updateItem(SocketCustom socket) async{
    try{
      var database = await socket.setup();
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
        case 'Checkbox':
          var elem = Element.fromJson(json);
          database.updateCheckBox((elem as CheckBox).id, elem.isChecked, elem.text, elem.idOrder);
          break;
        case 'Images':
          var elem = Element.fromJson(json);
          database.updateImage((elem as Images).id, elem.data, elem.idOrder);
          break;
        case 'Texts':
          var elem = Element.fromJson(json);
          database.updateTexts((elem as Texts).id, elem.text, elem.txtType.index, elem.idOrder);
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeAsym('success');
      print('success');
    }
    on EncryptionException{
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\nEncryption Exception');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
    on SocketException catch(e){ print('(Server)_updateObject: Connection lost with ${e.address}'); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
  }

  Future<void> _updateOrder(SocketCustom socket) async {
    try{
      var database = await socket.setup();
      var type = await socket.readAsym();
      await socket.synchronizeWrite();
      var jsonList = jsonDecode(await socket.readSym());

      switch(type){
        case 'sheet':
          var sheets = jsonToSheets(jsonList);
          database.updateSheetOrder(sheets);
          break;
        case 'element':
          var elements = jsonToElements(jsonList);
          database.updateElementOrder(elements);
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeAsym('success');
      print('success');
    }
    on EncryptionException{
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\nEncryption Exception');
    }
    on DatabaseException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
    on DatabaseTimeoutException catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
    on SocketException catch(e){ print('(Server)_updateObject: Connection lost with ${e.address}'); }
    catch(e){
      await socket.writeAsym('failed');
      print('(Server)_updateObject:\n$e');
    }
  }

  ///Convert a [list] of objects to a json
  ///To extract the json must be jsonDecode to get a list of json
  ///and each item in the list must be jsonDecode to recreate the object
  String listToJson(var list){
    var json = <String>[];
    for(var i = 0; i < list.length; i++){
      json.add(jsonEncode(list[i]));
    }
    return jsonEncode(json);
  }

  ///Convert a [jsonList] into a list of [Sheet]
  List<Sheet> jsonToSheets(List<Map<String, dynamic>> jsonList){
    var sheets = <Sheet>[];
    for(var i = 0; i < jsonList.length; i++){
      sheets.add(Sheet.fromJson(jsonList[i]));
    }
    return sheets;
  }

  ///Convert a [jsonList] into a list of [Element]
  List<Element> jsonToElements(List<Map<String, dynamic>> jsonList){
    var elements = <Element>[];
    for(var i = 0; i < jsonList.length; i++){
      elements.add(Element.fromJson(jsonList[i]));
    }
    return elements;
  }
}