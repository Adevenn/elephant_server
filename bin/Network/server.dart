import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../Exception/encryption_exception.dart';
import '../Model/cell.dart';
import '../Model/Elements/checkbox.dart';
import '../Model/Elements/element.dart';
import '../Model/Elements/image.dart';
import '../Model/Elements/text.dart';
import '../Model/sheet.dart';
import 'Encryption/asym_encryption.dart';
import 'socket_custom.dart';
import 'database.dart';

class Server {
  final String _ipServer;
  final int _portServer;
  final AsymEncryption _asym = AsymEncryption();
  final String _ipDatabase;
  final int _portDatabase;

  Server(
      this._ipServer, this._portServer, this._ipDatabase, this._portDatabase);

  void start() async {
    try {
      var server = await ServerSocket.bind(_ipServer, _portServer);
      print('/* Waiting for connections */');
      server.listen(_handleClient);
    } catch (e) {
      sleep(Duration(seconds: 2));
      start();
    }
  }

  void _handleClient(Socket _socket) async {
    var socket = SocketCustom(_socket, _asym, _ipDatabase, _portDatabase);
    try {
      var request = await socket.read();
      print('/* New request: $request */');
      switch (request) {
        case 'init':
          await _init(socket);
          break;
        case 'cells':
          await _cells(socket);
          break;
        case 'sheets':
          await _sheets(socket);
          break;
        case 'sheet':
          await _sheet(socket);
          break;
        case 'elements':
          await _elements(socket);
          break;
        case 'rawImage':
          await _rawImage(socket);
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
    } catch (e) {
      print('(Server)_handleClient:\n$e');
    }
    await socket.disconnect();
    print('--- Client disconnected ---');
  }

  ///Try to connect to database
  Future<void> _init(SocketCustom socket) async {
    try {
      var database = await socket.init();
      await database.testConnection();
      await socket.write('success');
    } on DatabaseTimeoutException catch (e) {
      await socket.write('databaseTimeout');
      print('(Server)_init:\n$e');
    } on SocketException {
      print('(Server)_init: Connection lost with ');
    } catch (e) {
      await socket.write('failed');
      print('(Server)_init:\n$e');
    }
  }

  ///Get cells from database and send it to client with [socket]
  ///
  /// Each cell is convert to json and encrypted
  Future<void> _cells(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      //Asym because matchWord could be null ('')
      var matchWord = await socket.readAsym();
      var cells = await database.selectCells(matchWord);
      await socket.writeBigString(listToJson(cells));
    } on SocketException {
      print('(Server)_cells: Client disconnected');
    } on EncryptionException {
      print('(Server)_cells:\nEncryption Exception');
    } on DatabaseException catch (e) {
      print('(Server)_cells:\n$e');
    } on DatabaseTimeoutException catch (e) {
      print('(Server)_cells:\n$e');
    } catch (e) {
      throw Exception('(Server)_cells:\n$e');
    }
  }

  ///Get the cell content from database
  Future<void> _sheets(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var idCell = int.parse(await socket.readSym());
      var sheets = await database.selectSheets(idCell);
      await socket.writeBigString(listToJson(sheets));
    } on SocketException {
      print('(Server)_sheets:\nSocketException');
    } on EncryptionException {
      print('(Server)_sheets:\nEncryption Exception');
    } on DatabaseException catch (e) {
      print('(Server)_sheets:\n$e');
    } on DatabaseTimeoutException catch (e) {
      print('(Server)_sheets:\n$e');
    } catch (e) {
      print('(Server)_sheets:\n$e');
    }
  }

  Future<void> _sheet(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var idCell = int.parse(await socket.readSym());
      await socket.synchronizeWrite();
      var sheetIndex = int.parse(await socket.readSym());
      await socket.writeBigString(
          jsonEncode(await database.selectSheet(idCell, sheetIndex)));
    } on SocketException {
      print('(Server)_sheet:\nSocketException');
    } on EncryptionException {
      print('(Server)_sheet:\nEncryption Exception');
    } on DatabaseException catch (e) {
      print('(Server)_sheet:\n$e');
    } on DatabaseTimeoutException catch (e) {
      print('(Server)_sheet:\n$e');
    } catch (e) {
      print('(Server)_sheet:\n$e');
    }
  }

  ///Get the sheet content from database
  Future<void> _elements(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var idSheet = int.parse(await socket.readSym());
      var elements = await database.selectElements(idSheet);
      await socket.writeBigString(listToJson(elements));
    } on SocketException {
      print('(Server)_elements:\nSocketException');
    } on EncryptionException {
      print('(Server)_elements:\nEncryption Exception');
    } on DatabaseException catch (e) {
      print('(Server)_elements:\n$e');
    } on DatabaseTimeoutException catch (e) {
      print('(Server)_elements:\n$e');
    } catch (e) {
      print('(Server)_elements:\n$e');
    }
  }

  Future<void> _rawImage(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var id = int.parse(await socket.readSym());
      var data = await database.selectRawImage(id);
      await socket.writeBigString(data);
    } on SocketException {
      print('(Server)_rawImage:\nSocketException');
    } on EncryptionException {
      print('(Server)_rawImage:\nEncryption Exception');
    } on DatabaseException catch (e) {
      print('(Server)_rawImage:\n$e');
    } on DatabaseTimeoutException catch (e) {
      print('(Server)_rawImage:\n$e');
    } catch (e) {
      print('(Server)_rawImage:\n$e');
    }
  }

  ///Receive a json containing a Cell
  ///Call database to add this Cell
  Future<void> _addCell(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var jsonObj = jsonDecode(await socket.readSym());
      var cell = Cell.fromJson(jsonObj);
      await database.addCell(cell.title, cell.subtitle, cell.type);
      await socket.writeBigString('success');
      print('success');
    } on EncryptionException {
      await socket.writeBigString('failed');
      print('(Server)_addCell\nEncryption Exception');
    } on DatabaseException catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addCell:\n$e');
    } on DatabaseTimeoutException catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addCell:\n$e');
    } on SocketException catch (e) {
      print('(Server)_addCell: Connection lost with ${e.address}');
    } catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addCell:\n$e');
    }
  }

  ///Receive a type and a json
  ///Call the database to add the jsonObject
  Future<void> _addItem(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var type = await socket.readBigString();
      await socket.synchronizeWrite();
      var json = jsonDecode(await socket.readBigString());
      switch (type) {
        case 'Sheet':
          var sheet = Sheet.fromJson(json);
          await database.addSheet(
              sheet.idParent, sheet.title, sheet.subtitle, sheet.idOrder);
          break;
        case 'Checkbox':
          var element = Element.fromJson(json);
          await database.addCheckbox(element.idParent);
          break;
        case 'Image':
          var element = Element.fromJson(json);
          await database.addImage(
              (element as Image).imgPreview, element.imgRaw, element.idParent);
          break;
        case 'Text':
          var element = Element.fromJson(json);
          await database.addText(
              (element as Text).txtType.index, element.idParent);
          break;
        default:
          throw Exception('(Server)_addItem: Wrong type -> $type');
      }
      await socket.writeBigString('success');
      print('success');
    } on EncryptionException catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addItem:\nEncryption Exception\n$e');
    } on DatabaseException catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addItem:\n$e');
    } on DatabaseTimeoutException catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addItem:\n$e');
    } on SocketException catch (e) {
      print('(Server)_addItem: Connection lost with ${e.address}');
    } catch (e) {
      await socket.writeBigString('failed');
      print('(Server)_addItem:\n$e');
    }
  }

  ///Receive a type and an index
  ///Call the database to delete the matching object
  Future<void> _deleteItem(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var type = await socket.readSym();
      await socket.synchronizeWrite();
      var idItem = int.parse(await socket.readSym());
      switch (type) {
        case 'Cell':
          await database.deleteCell(idItem);
          break;
        case 'Sheet':
          await database.deleteSheet(idItem);
          break;
        case 'Element':
          await database.deleteElement(idItem);
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeSym('success');
      print('success');
    } on EncryptionException {
      await socket.writeSym('failed');
      print('(Server)_deleteItem:\nEncryption Exception');
    } on DatabaseException catch (e) {
      await socket.writeSym('failed');
      print('(Server)_deleteItem:\n$e');
    } on DatabaseTimeoutException catch (e) {
      await socket.writeSym('failed');
      print('(Server)_deleteItem:\n$e');
    } on SocketException catch (e) {
      print('(Server)_deleteItem: Connection lost with ${e.address}');
    } catch (e) {
      await socket.writeSym('failed');
      print('(Server)_deleteItem:\n$e');
    }
  }

  ///Receive a type and a json
  ///
  ///Call database to update the jsonObject
  Future<void> _updateItem(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var type = await socket.readSym();
      await socket.synchronizeWrite();
      var json = jsonDecode(await socket.readBigString());
      switch (type) {
        case 'Cell':
          var cell = Cell.fromJson(json);
          database.updateCell(cell.id, cell.title, cell.subtitle);
          break;
        case 'Sheet':
          var sheet = Sheet.fromJson(json);
          database.updateSheet(sheet.id, sheet.title, sheet.subtitle);
          break;
        case 'Checkbox':
          var elem = Element.fromJson(json);
          database.updateCheckbox(
              (elem as Checkbox).id, elem.isChecked, elem.text);
          break;
        case 'Text':
          var elem = Element.fromJson(json);
          database.updateTexts(
              (elem as Text).id, elem.text, elem.txtType.index);
          break;
        default:
          throw Exception('Wrong object type');
      }
      await socket.writeSym('success');
      print('success');
    } on EncryptionException {
      await socket.writeSym('failed');
      print('(Server)_updateItem:\nEncryption Exception');
    } on DatabaseException catch (e) {
      await socket.writeSym('failed');
      print('(Server)_updateItem:\n$e');
    } on DatabaseTimeoutException catch (e) {
      await socket.writeSym('failed');
      print('(Server)_updateItem:\n$e');
    } on SocketException catch (e) {
      print('(Server)_updateItem: Connection lost with ${e.address}');
    } catch (e) {
      await socket.writeSym('failed');
      print('(Server)_updateItem:\n$e');
    }
  }

  Future<void> _updateOrder(SocketCustom socket) async {
    try {
      var database = await socket.setup();
      var type = await socket.readSym();
      await socket.synchronizeWrite();
      var jsonList = jsonDecode(await socket.readBigString());

      if (type == 'Sheet') {
        var sheets = jsonToSheets(jsonList);
        await database.updateSheetOrder(sheets);
      } else if (type == 'Element') {
        var elements = jsonToElements(jsonList);
        await database.updateElementOrder(elements);
      } else {
        throw Exception('Wrong object type');
      }
      await socket.writeSym('success');
      print('success');
    } on EncryptionException {
      await socket.writeSym('failed');
      print('(Server)_updateOrder:\nEncryption Exception');
    } on DatabaseException catch (e) {
      await socket.writeSym('failed');
      print('(Server)_updateOrder:\n$e');
    } on DatabaseTimeoutException catch (e) {
      await socket.writeSym('failed');
      print('(Server)_updateOrder:\n$e');
    } on SocketException catch (e) {
      print('(Server)_updateObject: Connection lost with ${e.address}');
    } catch (e) {
      await socket.writeSym('failed');
      print('(Server)_updateOrder:\n$e');
    }
  }

  ///Convert a [list] of objects to a json
  ///To extract the json must be jsonDecode to get a list of json
  ///and each item in the list must be jsonDecode to recreate the object
  String listToJson(var list) {
    var json = <String>[];
    for (var i = 0; i < list.length; i++) {
      json.add(jsonEncode(list[i]));
    }
    return jsonEncode(json);
  }

  ///Convert a [jsonList] into a list of [Sheet]
  List<Sheet> jsonToSheets(var jsonList) {
    var sheets = <Sheet>[];
    for (var i = 0; i < jsonList.length; i++) {
      sheets.add(Sheet.fromJson(jsonDecode(jsonList[i])));
    }
    return sheets;
  }

  ///Convert a [jsonList] into a list of [Element]
  List<Element> jsonToElements(var jsonList) {
    var elements = <Element>[];
    for (var i = 0; i < jsonList.length; i++) {
      elements.add(Element.fromJson(jsonDecode(jsonList[i])));
    }
    return elements;
  }
}
