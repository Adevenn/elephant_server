import 'dart:io';
import 'dart:convert';

import '../Exception/database_exception.dart';
import '../Exception/server_exception.dart';
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
    print('/* WAITING FOR REQUESTS */');

    await for (HttpRequest request in server) {
      print('/* NEW REQUEST : ${request.requestedUri.path} */');
      if (request.method == 'POST' &&
          request.headers.contentType?.mimeType == 'application/json') {
        try {
          var requestJson = jsonDecode(await utf8.decoder.bind(request).join());
          //print(requestJson);
          var db = requestJson['database'];
          var username = requestJson['username'];
          var password = requestJson['password'];
          var json = jsonDecode(requestJson['json']);
          switch (request.requestedUri.path) {
            case '/init':
              await _api.test(db, username, password);
              await _responseOK(request, 'test ok');
              break;
            case '/cells':
              var cells = await _api.selectCells(db, username, password, json);
              await _responseOK(request, jsonEncode(cells));
              break;
            case '/sheets':
              var sheets =
                  await _api.selectSheets(db, username, password, json);
              await _responseOK(request, jsonEncode(sheets));
              break;
            case '/sheet':
              var sheet = await _api.selectSheet(db, username, password, json);
              await _responseOK(request, jsonEncode(sheet));
              break;
            case '/elements':
              var elements =
                  await _api.selectElements(db, username, password, json);
              await _responseOK(request, jsonEncode(elements));
              break;
            case '/rawImage':
              var img = await _api.selectRawImage(db, username, password, json);
              await _responseOK(request, jsonEncode(img));
              break;
            case '/addCell':
              await _api.addCell(db, username, password, json);
              await _responseOK(request, 'cell added correctly');
              break;
            case '/addSheet':
              await _api.addSheet(db, username, password, json);
              await _responseOK(request, 'sheet added correctly');
              break;
            case '/addCheckbox':
              await _api.addCheckbox(db, username, password, json);
              await _responseOK(request, 'checkbox added correctly');
              break;
            case '/addImage':
              await _api.addImage(db, username, password, json);
              await _responseOK(request, 'image added correctly');
              break;
            case '/addText':
              await _api.addText(db, username, password, json);
              await _responseOK(request, 'text added correctly');
              break;
            case '/deleteCell':
              await _api.deleteCell(db, username, password, json);
              await _responseOK(request, 'cell deleted correctly');
              break;
            case '/deleteSheet':
              await _api.deleteSheet(db, username, password, json);
              await _responseOK(request, 'sheet deleted correctly');
              break;
            case '/deleteElement':
              await _api.deleteElement(db, username, password, json);
              await _responseOK(request, 'element deleted correctly');
              break;
            case '/updateCell':
              await _api.updateCell(db, username, password, json);
              await _responseOK(request, 'cell updated correctly');
              break;
            case '/updateSheet':
              await _api.updateSheet(db, username, password, json);
              await _responseOK(request, 'sheet updated correctly');
              break;
            case '/updateCheckbox':
              await _api.updateCheckbox(db, username, password, json);
              await _responseOK(request, 'checkbox updated correctly');
              break;
            case '/updateText':
              await _api.updateText(db, username, password, json);
              await _responseOK(request, 'text updated correctly');
              break;
            case '/updateSheetOrder':
              await _api.updateSheetOrder(db, username, password, json);
              await _responseOK(request, 'sheet order updated correctly');
              break;
            case '/updateElementOrder':
              await _api.updateElementOrder(db, username, password, json);
              await _responseOK(request, 'element order updated correctly');
              break;
            default:
              request.response
                ..statusCode = HttpStatus.notFound
                ..write('404 Not Found');
              break;
          }
        } on DatabaseException catch (e) {
          _dbError(request, e);
        } on ServerException catch (e) {
          _serverError(request, e);
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('404 Not Found');
      }
      await request.response.close();
      print('/* REQUEST DONE : ${request.requestedUri.path} */');
    }
  }

  Future<void> _responseOK(HttpRequest request, String body) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..write(body);
  }

  void _serverError(HttpRequest request, ServerException e) {
    print('*** Exception $e');
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('500 Internal Server Error');
  }

  void _dbError(HttpRequest request, DatabaseException e) {
    print('*** Exception $e');
    request.response
      ..statusCode = HttpStatus.serviceUnavailable
      ..write('503 ServiceUnavailable');
  }
}
