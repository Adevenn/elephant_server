import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';

import '../Model/cell.dart';
import '../Model/CellComponents/book.dart';
import '../Model/CellComponents/ranking.dart';
import '../Model/CellComponents/to_do_list.dart';
import '../Model/Elements/checkbox.dart';
import '../Model/Elements/element.dart';
import '../Model/Elements/image.dart';
import '../Model/Elements/text_type.dart';
import '../Model/Elements/text.dart';
import '../Model/sheet.dart';

class Database{
  late PostgreSQLConnection _connection;
  late String _ip, _database, _username, _password;
  late int _port;

  Database(String ip, int port, String db, String username, String password){
    _ip = ip;
    _port = port;
    _database = db;
    _username = username;
    _password = password;
  }

  List<Element> sortByIdOrder(List<Element> elements){
    var isSort = true;
    while(true){
      for(var i = 1; i < elements.length; i++){
        if(elements[i].idOrder < elements[i-1].idOrder){
          var elem = elements[i];
          elements[i] = elements[i-1];
          elements[i-1] = elem;
          isSort = false;
        }
      }
      if(isSort){
        break;
      }
      isSort = true;
    }
    return elements;
  }

  Future<void> _initConnection() async{
    _connection = PostgreSQLConnection(_ip, _port, _database, username: _username, password: _password, timeoutInSeconds: 3);
    try{ await _connection.open(); }
    on PostgreSQLException { throw DatabaseException('(Database)_initConnection: Wrong DATABASE ($_database), USERNAME ($_username) or PASSWORD ($_password)'); }
    on TimeoutException { throw DatabaseTimeoutException('(Database)_initConnection: Database disconnected'); }
    catch(e) { throw Exception('(Database)_initConnection: Connection failed\n$e'); }
  }

  Future<void> testConnection() async{
    try{
      await _initConnection();
      await _connection.close();
    }
    on DatabaseException catch(e){ throw DatabaseException('$e'); }
    on DatabaseTimeoutException catch(e) { throw DatabaseTimeoutException('$e'); }
    on TimeoutException { throw DatabaseTimeoutException('(Database)_initConnection: Database disconnected or make too much time to answer'); }
    catch(e) { throw Exception(e); }
  }

  /// SELECT ///

  Future<List<Cell>> _cellsFromRawValues(PostgreSQLResult results) async{
    try{
      var cells = <Cell>[];
      for(final row in results) {
        switch(row[3] as int){
          case 0:
            cells.add(Book(row[0] as int, row[1] as String, row[2] as String));
            break;
          case 1:
            cells.add(ToDoList(id: row[0] as int, title: row[1] as String, subtitle: row[2] as String));
            break;
          case 2:
            cells.add(Ranking(id: row[0] as int, title: row[1] as String, subtitle: row[2] as String));
            break;
          default:
            throw Exception('Not an existing type of cell');
        }
      }
      return cells;
    }
    catch (e){ throw DatabaseException('(Database)_cellsFromRawValues:\n$e}'); }
  }

  Future<List<Cell>> selectCells(String matchWord) async{
    try{
      await _initConnection();
      var results = await _connection.query("SELECT * FROM cell WHERE title LIKE '%$matchWord%' ORDER BY title;");
      await _connection.close();
      return _cellsFromRawValues(results);
    }
    on TimeoutException { throw DatabaseTimeoutException('(Database)_initConnection: Database disconnected'); }
    catch(e){ throw DatabaseException('(Database)$e'); }
  }

  Future<List<Sheet>> selectSheets(int idCell) async{
    try{
      PostgreSQLResult sheetsRaw;
      var sheets = <Sheet>[];
      await _initConnection();
      sheetsRaw = await _connection.query('SELECT id, title, subtitle, idorder FROM sheet WHERE idcell = $idCell ORDER BY idorder;');
      await _connection.close();
      for(var i = 0; i < sheetsRaw.length; i++) {
        var sheet = Sheet(sheetsRaw[i][0] as int, idCell, sheetsRaw[i][1] as String, sheetsRaw[i][2] as String, sheetsRaw[i][3] as int);
        sheets.add(sheet);
      }
      return sheets;
    }
    on PostgreSQLException{ throw DatabaseException(''); }
    on TimeoutException { throw DatabaseTimeoutException('(Database)_initConnection: Database disconnected'); }
    catch(e) { throw DatabaseException('(Database)$e'); }
  }

  Future<List<Element>> selectElements(int idSheet) async{
    try{
      var elems = <Element>[];
      PostgreSQLResult checkboxes, images, texts;
      await _initConnection();
      checkboxes = await _connection.query('SELECT id, text, is_checked, elem_order FROM checkbox WHERE id_sheet = $idSheet ORDER BY elem_order;');
      images = await _connection.query('SELECT id, data, elem_order FROM image WHERE id_sheet = $idSheet ORDER BY elem_order;');
      texts = await _connection.query('SELECT id, text, type, elem_order FROM text WHERE id_sheet = $idSheet ORDER BY elem_order;');
      await _connection.close();

      //Extract data from db values and create objects
      for(final elem in checkboxes) {
        elems.add(Checkbox(id: elem[0] as int, idParent: idSheet, text: elem[1] as String, isChecked: elem[2] as bool, idOrder: elem[3] as int));
      }
      for(final elem in images) {
        var datas = jsonDecode(elem[1]);
        print(datas);

        elems.add(Image(id: elem[0] as int, idParent: idSheet,data: Uint8List.fromList(datas['data'].cast<int>()), idOrder: elem[2] as int));
      }
      for(final elem in texts) {
        elems.add(Text(id: elem[0] as int, idParent: idSheet,text: elem[1] as String, txtType: TextType.values[elem[2] as int], idOrder: elem[3] as int));
      }

      if(elems.length > 1){
        elems = sortByIdOrder(elems);
      }
      return elems;
    }
    on PostgreSQLException catch(e){ throw DatabaseException('(Database)selectElements:\n$e'); }
    catch(e) { throw Exception(e); }
  }

  /// ADD ///

  Future<void> addCell(String title, String subtitle, String type) async{
    try{
      int typeInt;
      switch(type){
        case 'Book':
          typeInt = 0;
          break;
        case 'ToDoList':
          typeInt = 1;
          break;
        case 'Ranking':
          typeInt = 2;
          break;
        default:
          throw Exception('Unexpected cell type');
      }
      await _initConnection();
      await _connection.query("INSERT INTO cell (title, subtitle, type) VALUES ('$title', '$subtitle', $typeInt);");
      var idCellRaw = await _connection.query("SELECT id FROM cell WHERE cell.title = '$title';");
      var idCell = idCellRaw[0][0] as int;
      await _connection.query("INSERT INTO sheet (idcell, title, subtitle, idorder) VALUES ($idCell, 'New Sheet', '', 0);");
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)addCell: Connection lost\n$e'); }
  }

  Future<void> addSheet(int idCell, String title, String subtitle, int idOrder) async{
    try{
      await _initConnection();
      await _connection.query("SELECT add_sheet($idCell::bigint, \'$title\'::text, \'$subtitle\'::text);");
      await _connection.close();
    }
    on PostgreSQLException catch(e) { throw DatabaseException('(Database)addSheet: Wrong entries\n$e'); }
    catch(e) { throw DatabaseException('(Database)addSheet: Connection lost\n$e'); }
  }

  Future<void> addCheckbox(int idSheet) async{
    try{
      await _initConnection();
      await _connection.query('SELECT add_checkbox($idSheet::bigint);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)addCheckbox: Connection lost\n$e'); }
  }

  //Can't store Uint8List directly into postresql
  //Error: PostgreSQLSeverity.error 42601: syntax error at or near "["
  Future<void> addImage(Uint8List data, int idSheet) async{
    try{
      var dataMap = {'data':data};
      var json = jsonEncode(dataMap);
      print(json);
      await _initConnection();
      /*await _connection.query('INSERT INTO image (id_sheet, data, elem_order)'
          ' VALUES ($idSheet::bigint, $data::bytea, 0::integer);');*/
      await _connection.query('SELECT add_image($idSheet::bigint, \'$json\'::text);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)addImage: Connection lost\n$e'); }
  }

  Future<void> addText(int type, int idSheet) async{
    try{
      await _initConnection();
      await _connection.query('SELECT add_text($idSheet::bigint, $type::integer);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)add_text: Connection lost\n$e'); }
  }

  /// DELETE ///

  Future<void> deleteCell(int idCell) async{
    try{
      await _initConnection();
      await _connection.query('DELETE FROM cell WHERE id = $idCell;');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)deleteCell: Connection lost\n$e'); }
  }

  Future<void> deleteSheet(int idSheet) async{
    try{
      await _initConnection();
      var ids = <int>[], orders = <int>[];
      var sheetsRaw = await _connection.query('SELECT * from delete_sheet(CAST($idSheet as bigint));');
      for(var row in sheetsRaw){
        ids.add(row[0] as int);
        orders.add(row[1] as int);
      }
      //Sort sheets
      if(ids.length > 1){
        for(var i = 0; i < ids.length; i++){
          if(orders[i] != i){
            await _connection.query('UPDATE sheet SET idorder = $i WHERE sheet.id = ${ids[i]};');
          }
        }
      }
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)deleteSheet: Connection lost\n$e'); }
  }

  Future<void> deleteElement(int idElement) async{
    try{
      var ids = <int>[], orders = <int>[];
      await _initConnection();
      var elementsRaw = await _connection.query('SELECT * from delete_element(CAST($idElement as bigint));');
      if(elementsRaw.length > 1){
        for(var row in elementsRaw){
          ids.add(row[0] as int);
          orders.add(row[1] as int);
        }
        await updateDatabaseElementOrder(ids, orders);
      }
      await _connection.close();
    }
    catch(e) { throw DatabaseException('(Database)deleteElement:\n$e'); }
  }

  /// UPDATE ///

  void updateCell(int id, String title, String subtitle) async{
    try{
      await _initConnection();
      await _connection.query("UPDATE cell SET title = '$title', subtitle = '$subtitle' WHERE id = $id;");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateCell: Connection lost\n$e'); }
  }

  void updateSheet(int id, String title, String subtitle, int idOrder) async{
    try{
      await _initConnection();
      await _connection.query("UPDATE sheet SET title = '$title', subtitle = '$subtitle', idorder = $idOrder WHERE id = $id;");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateSheet: Connection lost\n$e'); }
  }

  void updateCheckBox(int id, bool isCheck, String text, int idOrder) async{
    try{
      await _initConnection();
      await _connection.query("UPDATE checkbox SET is_checked = $isCheck, text = '$text', elem_order = $idOrder WHERE id = $id;");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateCheckbox: Connection lost\n$e'); }
  }

  void updateImage(int id, List<int> data, int idOrder) async{
    try{
      await _initConnection();
      await _connection.query('UPDATE image SET data = $data, elem_order = $idOrder WHERE id = $id;');
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateImage: Connection lost\n$e'); }
  }

  void updateTexts(int id, String text, int type, int idOrder) async {
    try {
      await _initConnection();
      await _connection.query("UPDATE text SET text = '$text', type = $type, elem_order = $idOrder WHERE id = $id;");
      await _connection.close();
    } catch (e) { throw DatabaseException('(Database)updateTexts: Connection lost\n$e'); }
  }

  Future<void> updateSheetOrder(List<Sheet> sheets) async{
    try{
      await _initConnection();
      for(var i = 0; i < sheets.length; i++){
        if(sheets[i].idOrder != i){
          await _connection.query('UPDATE sheet SET idorder = ${sheets[i].idOrder} WHERE id = ${sheets[i].id}');
        }
      }
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)updateSheetOrder:\n$e'); }
  }

  Future<void> updateElementOrder(List<Element> elements) async{
    try{
      var ids = <int>[], orders = <int>[];
      for(var i = 0; i < elements.length; i++){
        ids.add(elements[i].id);
        orders.add(elements[i].idOrder);
      }
      await _initConnection();
      await updateDatabaseElementOrder(ids, orders);
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)updateElementOrder:\n$e'); }
  }

  Future<void> updateDatabaseElementOrder(List<int> ids, List<int> orders) async{
    for(var i = 0; i < ids.length; i++){
      if(orders[i] != i){
        await _connection.query('UPDATE element SET elem_order = $i WHERE id = ${ids[i]};');
      }
    }
  }
}

class DatabaseException implements Exception{
  final String message;

  DatabaseException([this.message = '']);

  @override
  String toString() => 'Wrong database identifiers: $message';
}

class DatabaseTimeoutException implements Exception{
  final String message;

  DatabaseTimeoutException([this.message = '']);

  @override
  String toString() => 'Database connection lost: $message';
}