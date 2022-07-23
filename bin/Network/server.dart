import 'dart:io';
import 'dart:convert';

import '../Exception/database_exception.dart';
import '../Exception/server_exception.dart';
import '../Model/constants.dart';
import 'api.dart';
import 'authenticate_db.dart';

class Server {
  late final API _api;
  late final AuthenticateDB _authDB;

  Server(String authUsername, String authPassword, String dataUsername,
      String dataPassword) {
    _authDB = AuthenticateDB(authUsername: authUsername, authPwd: authPassword);
    _api = API(dataUsername, dataPassword);
  }

  void start() async {
    var server =
        await HttpServer.bind(Constants.serverIP, Constants.serverPort);
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
          var username = requestJson['username'];
          var password = requestJson['password'];
          if (request.requestedUri.path == '/add_account') {
            try {
              await _authDB.tryAddAccount(username, password);
              await _responseOK(request, 'Add account success');
            } catch (e) {
              throw DatabaseException();
            }
          } else {
            try {
              await _authDB.trySignIn(username, password);
              var json = jsonDecode(requestJson['json']);
              switch (request.requestedUri.path) {
                case '/sign_in':
                  await _responseOK(request, 'Sign in success');
                  break;
                case '/cells':
                  var cells = await _api.selectCells(username, json);
                  await _responseOK(request, jsonEncode(cells));
                  break;
                case '/sheets':
                  var sheets = await _api.selectSheets(json);
                  await _responseOK(request, jsonEncode(sheets));
                  break;
                case '/sheet':
                  var sheet = await _api.selectSheet(json);
                  await _responseOK(request, jsonEncode(sheet));
                  break;
                case '/elements':
                  var elements = await _api.selectElements(json);
                  print(jsonEncode(elements));
                  await _responseOK(request, jsonEncode(elements));
                  break;
                case '/rawImage':
                  var img = await _api.selectRawImage(json);
                  await _responseOK(request, jsonEncode(img));
                  break;
                case '/addCell':
                  await _api.addCell(json);
                  await _responseOK(request, 'cell added correctly');
                  break;
                case '/addSheet':
                  await _api.addSheet(json);
                  await _responseOK(request, 'sheet added correctly');
                  break;
                case '/addCheckbox':
                  await _api.addCheckbox(json);
                  await _responseOK(request, 'checkbox added correctly');
                  break;
                case '/addImage':
                  await _api.addImage(json);
                  await _responseOK(request, 'image added correctly');
                  break;
                case '/addText':
                  await _api.addText(json);
                  await _responseOK(request, 'text added correctly');
                  break;
                case '/addFlashcard':
                  await _api.addFlashcard(json);
                  await _responseOK(request, 'flashcard added correctly');
                  break;
                case '/deleteItem':
                  await _api.delete(json);
                  await _responseOK(request, 'item deleted correctly');
                  break;
                case '/updateCell':
                  await _api.updateCell(json);
                  await _responseOK(request, 'cell updated correctly');
                  break;
                case '/updateSheet':
                  await _api.updateSheet(json);
                  await _responseOK(request, 'sheet updated correctly');
                  break;
                case '/updateCheckbox':
                  await _api.updateCheckbox(json);
                  await _responseOK(request, 'checkbox updated correctly');
                  break;
                case '/updateText':
                  await _api.updateText(json);
                  await _responseOK(request, 'text updated correctly');
                  break;
                case '/updateSheetOrder':
                  await _api.updateSheetOrder(json);
                  await _responseOK(request, 'sheet order updated correctly');
                  break;
                case '/updateElementOrder':
                  await _api.updateElementOrder(json);
                  await _responseOK(request, 'element order updated correctly');
                  break;
                default:
                  request.response
                    ..statusCode = HttpStatus.notFound
                    ..write('404 Not Found');
                  break;
              }
            } catch (e) {
              throw DatabaseException('$e');
            }
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
    print('*** Server Error (code 500) :\n$e');
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('500 Internal Server Error');
  }

  void _dbError(HttpRequest request, DatabaseException e) {
    print('*** Database Error (code 503) :\n$e');
    request.response
      ..statusCode = HttpStatus.serviceUnavailable
      ..write('503 ServiceUnavailable');
  }
}
