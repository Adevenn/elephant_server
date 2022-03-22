import 'dart:io';
import 'dart:convert';

import '../Exception/database_exception.dart';
import 'api.dart';

class Server {
  final String _ipServer;
  final int _portServer;
  late final API _api;

  Server(this._ipServer, this._portServer, String ipDb, int portDb) {
    _api = API(ipDb, portDb);
  }

  void start() async {
    var server = await HttpServer.bind(_ipServer, _portServer);
    //https
    /*var server = await HttpServer.bindSecure('127.0.0.1', 443,
        SecurityContext());*/

    await for (HttpRequest request in server) {
      print('NEW REQUEST : ${request.requestedUri.path}\n');
      if (request.method == 'POST' &&
          request.headers.contentType?.mimeType == 'application/json') {
        var json = jsonDecode(await utf8.decoder.bind(request).join());
        print('content : $json');
        switch (request.requestedUri.path) {
          case '/init':
            init(request, json);
            break;
          case '/cells':
            cells(request, json);
            break;
          case '/sheets':
            sheets(request, json);
            break;
          case '/sheet':
            sheet(request, json);
            break;
          case '/elements':
            elements(request, json);
            break;
          case '/addCell':
            addCell(request, json);
            break;
          case '/addSheet':
            addSheet(request, json);
            break;
          case '/addCheckbox':
            addCheckbox(request, json);
            break;
          case '/addImage':
            addImage(request, json);
            break;
          case '/addText':
            addText(request, json);
            break;
          case '/deleteCell':
            deleteCell(request, json);
            break;
          case '/deleteSheet':
            deleteSheet(request, json);
            break;
          case '/deleteElement':
            deleteElement(request, json);
            break;
          case '/updateCell':
            updateCell(request, json);
            break;
          case '/updateSheet':
            updateSheet(request, json);
            break;
          case '/updateCheckbox':
            updateCheckbox(request, json);
            break;
          case '/updateText':
            updateText(request, json);
            break;
          case '/updateSheetOrder':
            updateSheetOrder(request, json);
            break;
          case '/updateElementOrder':
            updateElementOrder(request, json);
            break;
          default:
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('404 Not Found');
            break;
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('404 Not Found');
      }
      await request.response.close();
    }
  }

  void _serverError(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('500 Internal Server Error');
  }

  void _dbError(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.serviceUnavailable
      ..write('503 ServiceUnavailable');
  }

  ///Test db connection
  void init(HttpRequest request, Map json) {
    try {
      _api.test(json['database'], json['username'], json['password']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('test ok');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  /// SELECT ///

  ///Get cells
  void cells(HttpRequest request, Map json) async {
    try {
      var cells = await _api.selectCells(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(cells));
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Get sheets
  void sheets(HttpRequest request, Map json) async {
    try {
      var sheets = await _api.selectSheets(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(sheets));
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Get specific sheet
  void sheet(HttpRequest request, Map json) async {
    try {
      var sheet = await _api.selectSheet(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(sheet));
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Get elements
  void elements(HttpRequest request, Map json) async {
    try {
      var elements = await _api.selectElements(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(elements));
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Get raw image
  void rawImage(HttpRequest request, Map json) async {
    try {
      var img = await _api.selectRawImage(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(img));
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  /// ADD ///

  ///Add cell
  void addCell(HttpRequest request, Map json) async {
    try {
      await _api.addCell(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Add sheet
  void addSheet(HttpRequest request, Map json) async {
    try {
      await _api.addSheet(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Add checkbox
  void addCheckbox(HttpRequest request, Map json) async {
    try {
      await _api.addCheckbox(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Add image
  void addImage(HttpRequest request, Map json) async {
    try {
      await _api.addImage(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Add text
  void addText(HttpRequest request, Map json) async {
    try {
      await _api.addText(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  /// DELETE ///

  ///Delete cell
  void deleteCell(HttpRequest request, Map json) async {
    try {
      await _api.deleteCell(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Delete sheets
  void deleteSheet(HttpRequest request, Map json) async {
    try {
      await _api.deleteSheet(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Delete element
  void deleteElement(HttpRequest request, Map json) async {
    try {
      await _api.deleteElement(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  /// UPDATE ///

  ///Update cell
  void updateCell(HttpRequest request, Map json) async {
    try {
      await _api.updateCell(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Update sheet
  void updateSheet(HttpRequest request, Map json) async {
    try {
      await _api.updateSheet(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Update checkbox
  void updateCheckbox(HttpRequest request, Map json) async {
    try {
      await _api.updateCheckbox(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Update text
  void updateText(HttpRequest request, Map json) async {
    try {
      await _api.updateText(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Update sheet order
  void updateSheetOrder(HttpRequest request, Map json) async {
    try {
      await _api.updateSheetOrder(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }

  ///Update element order
  void updateElementOrder(HttpRequest request, Map json) async {
    try {
      await _api.updateElementOrder(
          json['database'], json['username'], json['password'], json['json']);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('process done');
    } on DatabaseException catch (e) {
      _dbError(request);
    }
  }
}
