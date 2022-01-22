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
    for(var i = 1; i < elements.length; i++){
      if(elements[i].idOrder < elements[i-1].idOrder){
        var elem = elements[i];
        elements[i] = elements[i-1];
        elements[i-1] = elem;
        i = 0;
      }
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
    } catch (e){ throw DatabaseException('(Database)_cellsFromRawValues:\n$e}'); }
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
    on PostgreSQLException catch(e){ throw DatabaseException('(Database)selectSheets:\n$e'); }
    on TimeoutException { throw DatabaseTimeoutException('(Database)_initConnection: Database disconnected'); }
    catch(e) { throw DatabaseException('(Database)selectSheets\n$e'); }
  }

  Future<List<Element>> selectElements(int idSheet) async{
    try{
      var elems = <Element>[];
      PostgreSQLResult checkboxes, images, texts;
      await _initConnection();
      checkboxes = await _connection.query('SELECT id, text, is_checked, elem_order FROM checkbox WHERE id_sheet = $idSheet ORDER BY elem_order;');
      images = await _connection.query('SELECT id, image_preview, elem_order FROM image WHERE id_sheet = $idSheet ORDER BY elem_order;');
      texts = await _connection.query('SELECT id, text, type, elem_order FROM text WHERE id_sheet = $idSheet ORDER BY elem_order;');
      await _connection.close();

      //Extract data from db values and create objects
      for(final elem in checkboxes) {
        elems.add(Checkbox(id: elem[0] as int, idParent: idSheet, text: elem[1] as String, isChecked: elem[2] as bool, idOrder: elem[3] as int));
      }
      for(final elem in images) {
        var data = jsonDecode(elem[1]);
        elems.add(Image(id: elem[0] as int, idParent: idSheet, imgPreview: Uint8List.fromList(data['img_preview'].cast<int>()), idOrder: elem[2] as int));
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

  Future<String> selectRawImage(int idImg) async{
    try{
      await _initConnection();
      var rawImgResult = await _connection.query('SELECT image_raw FROM image WHERE id = $idImg;');
      for(final rawImg in rawImgResult){
        return rawImg[0] as String;
      }
      throw Exception('No rawImage found with id : $idImg');
    }
    catch(e){ throw Exception(e); }
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
      await _connection.query("CALL add_cell('$title'::text, '$subtitle'::text, $typeInt::integer);");
      await _connection.close();
    }
    on PostgreSQLException catch(e) { throw DatabaseException('(Database)addCell: Wrong entries\n$e'); }
    catch(e) { throw DatabaseException('(Database)addCell: Connection lost\n$e'); }
  }

  Future<void> addSheet(int idCell, String title, String subtitle, int idOrder) async{
    try{
      await _initConnection();
      await _connection.query("CALL add_sheet($idCell::bigint, '$title'::text, '$subtitle'::text);");
      await _connection.close();
    }
    on PostgreSQLException catch(e) { throw DatabaseException('(Database)addSheet: Wrong entries\n$e'); }
    catch(e) { throw DatabaseException('(Database)addSheet: Connection lost\n$e'); }
  }

  Future<void> addCheckbox(int idSheet) async{
    try{
      await _initConnection();
      await _connection.query('CALL add_checkbox($idSheet::bigint);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)addCheckbox: Connection lost\n$e'); }
  }

  Future<void> addImage(Uint8List imgPreview, Uint8List? imgRaw, int idSheet) async{
    try{
      var jsonImgPreview = jsonEncode({'img_preview' : imgPreview});
      var jsonImgRaw = jsonEncode({'img_raw' : imgRaw});
      await _initConnection();
      await _connection.query("CALL add_image($idSheet::bigint, '$jsonImgPreview'::text, '$jsonImgRaw'::text);");
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)addImage: Connection lost\n$e'); }
  }

  Future<void> addText(int type, int idSheet) async{
    try{
      await _initConnection();
      await _connection.query('CALL add_text($idSheet::bigint, $type::integer);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)add_text: Connection lost\n$e'); }
  }

  /// DELETE ///

  Future<void> deleteCell(int idCell) async{
    try{
      await _initConnection();
      await _connection.query('CALL delete_cell($idCell::bigint);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)deleteCell: Connection lost\n$e'); }
  }

  Future<void> deleteSheet(int idSheet) async{
    try{
      await _initConnection();
      await _connection.query('CALL delete_sheet($idSheet::bigint);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)deleteSheet: Connection lost\n$e'); }
  }

  Future<void> deleteElement(int idElement) async{
    try{
      await _initConnection();
      await _connection.query('CALL delete_element($idElement::bigint);');
      await _connection.close();
    } catch(e) { throw DatabaseException('(Database)deleteElement:\n$e'); }
  }

  /// UPDATE ///

  void updateCell(int id, String title, String subtitle) async{
    try{
      await _initConnection();
      await _connection.query("CALL update_cell($id::bigint, '$title'::text, '$subtitle'::text);");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateCell: Connection lost\n$e'); }
  }

  void updateSheet(int id, String title, String subtitle) async{
    try{
      await _initConnection();
      await _connection.query("CALL update_sheet($id::bigint, '$title'::text, '$subtitle'::text);");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateSheet: Connection lost\n$e'); }
  }

  void updateCheckbox(int id, bool isCheck, String text) async{
    try{
      await _initConnection();
      await _connection.query("CALL update_checkbox($id::bigint, $isCheck::boolean, '$text'::text);");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateCheckbox: Connection lost\n$e'); }
  }

  void updateTexts(int id, String text, int type) async {
    try {
      await _initConnection();
      await _connection.query("CALL update_text($id::bigint, '$text'::text);");
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateTexts: Connection lost\n$e'); }
  }

  Future<void> updateSheetOrder(List<Sheet> sheets) async{
    try{
      await _initConnection();
      for(var i = 0; i < sheets.length; i++){
        if(sheets[i].idOrder != i){
          await _connection.query('CALL update_sheet_order(${sheets[i].id}::bigint, ${sheets[i].idOrder}::int);');
        }
      }
      await _connection.close();
    } catch(e){ throw DatabaseException('(Database)updateSheetOrder:\n$e'); }
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
    } catch(e){ throw DatabaseException('(Database)updateElementOrder:\n$e'); }
  }

  Future<void> updateDatabaseElementOrder(List<int> ids, List<int> orders) async{
    for(var i = 0; i < ids.length; i++){
      if(orders[i] != i){
        await _connection.query('CALL update_element_order(${ids[i]}::bigint, $i::int;');
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