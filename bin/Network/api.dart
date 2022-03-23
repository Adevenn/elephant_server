import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../Exception/database_exception.dart';
import '../Model/cell.dart';
import '../Model/Elements/element.dart';
import '../Model/Elements/image.dart';
import '../Model/Elements/text_type.dart';
import '../Model/Elements/text.dart';
import '../Model/Cells/Book/sheet.dart';
import 'database.dart';

class API {
  final _className = 'API';
  late final DB db;

  API(String ip, int port) {
    db = DB(ip, port);
  }

  ///DB values -> List<Cell>
  List<Cell> _resultToCells(List<dynamic> result) {
    try {
      var cells = <Cell>[];
      for (final row in result) {
        print(row);
        cells.add(Cell.fromJson(row['cell']));
      }
      return cells;
    } catch (e) {
      print('ERROR IN RESULT TO CELL');
      throw DatabaseException('$e');
    }
  }

  ///DB values -> List<Sheet>
  List<Sheet> _resultToSheets(List<dynamic> result) {
    try {
      var sheets = <Sheet>[];
      for (final row in result) {
        sheets.add(Sheet.fromJson(row['sheet']));
      }
      return sheets;
    } catch (e) {
      throw DatabaseException('$e');
    }
  }

  ///DB values -> List<Element>
  List<Element> _resultToElems(List<dynamic> result, int idSheet) {
    var elems = <Element>[];
    for (final row in result) {
      if (row['checkbox'] != null) {
        elems.add(Element.fromJson(row['checkbox']));
      } else if (row['image'] != null) {
        elems.add(Element.fromJson(row['image']));
      } else if (row['text'] != null) {
        elems.add(Element.fromJson(row['text']));
      }
    }

    if (elems.length > 1) {
      elems.sort((a, b) => a.idOrder.compareTo(b.idOrder));
    }
    return elems;
  }

  ///Test connection with database
  Future<void> test(String database, username, password) async {
    try {
      await db.test(database, username, password);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.test:\n$e');
    }
  }

  /// SELECT ///

  ///Select cells from database that match with [matchWord]
  Future<List<Cell>> selectCells(
      String database, username, password, Map json) async {
    try {
      var matchWord = json['match_word'];
      var request = "select * from cell where title like '%$matchWord%';";
      var result =
          await db.queryWithResult(request, database, username, password);
      return _resultToCells(result);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectCells:\n$e');
    }
  }

  ///Select sheets from database that match with [id_cell]
  Future<List<Sheet>> selectSheets(
      String database, username, password, Map json) async {
    try {
      var idCell = json['id_cell'];
      var request = 'SELECT * FROM sheet WHERE '
          'id_cell = $idCell ORDER BY sheet_order;';
      var result =
          await db.queryWithResult(request, database, username, password);
      return _resultToSheets(result);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectSheets\n$e');
    }
  }

  ///Select sheet from database that match with [id_cell] and [sheet_index]
  Future<Sheet> selectSheet(String database, username, password, json) async {
    try {
      var idCell = json['id_cell'], sheetIndex = json['sheet_index'];
      var request = 'SELECT * FROM sheet WHERE id_cell = $idCell AND '
          'sheet_order = $sheetIndex;';
      var result =
          await db.queryWithResult(request, database, username, password);
      print(result);
      return Sheet.fromJson(result[0]['sheet']);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectSheet\n$e');
    }
  }

  ///Select elements from database that match with [id_sheet]
  Future<List<Element>> selectElements(
      String database, username, password, json) async {
    try {
      var idSheet = json['id_sheet'];
      List<dynamic> cb, img, txt;
      var requestCb = 'SELECT * FROM checkbox '
          'WHERE id_sheet = $idSheet ORDER BY elem_order;';
      cb = await db.queryWithResult(requestCb, database, username, password);

      var requestImg = 'SELECT * FROM image WHERE '
          'id_sheet = $idSheet ORDER BY elem_order;';
      img = await db.queryWithResult(requestImg, database, username, password);

      var requestTxt = 'SELECT * FROM text WHERE '
          'id_sheet = $idSheet ORDER BY elem_order;';
      txt = await db.queryWithResult(requestTxt, database, username, password);

      var elems = cb + img + txt;
      return _resultToElems(elems, idSheet);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectElements:\n$e');
    }
  }

  ///Select image from database that match with [id_img]
  Future<String> selectRawImage(
      String database, username, password, json) async {
    try {
      var idImg = json['id_img'];
      var request = 'SELECT image_raw FROM image WHERE id = $idImg;';
      var rawImg =
          await db.queryWithResult(request, database, username, password);
      print(rawImg[0]['image']['image_raw']);
      return rawImg[0]['image']['image_raw'];
    } catch (e) {
      throw Exception('$_className.selectRawImage:\n$e');
    }
  }

  /// ADD ///

  Future<void> addCell(String database, username, password, json) async {
    try {
      String title = json['title'],
          subtitle = json['subtitle'],
          type = json['type'];
      var request = "CALL add_cell('$title'::text, '$subtitle'::text, "
          "'$type'::text);";
      await db.query(request, database, username, password);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.addCell:\n$e');
    }
  }

  Future<void> addSheet(String database, username, password, json) async {
    try {
      var idCell = json['id_cell'],
          title = json['title'],
          subtitle = json['subtitle'];
      var request =
          "select add_sheet($idCell::bigint, '$title'::text, '$subtitle'::text"
          ");";
      await db.query(request, database, username, password);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.addSheet: Wrong entries\n$e');
    } catch (e) {
      throw DatabaseException('$_className.addSheet: Connection lost\n$e');
    }
  }

  Future<void> addCheckbox(String database, username, password, json) async {
    try {
      var idSheet = json['id_sheet'];
      var request = 'CALL add_checkbox($idSheet::bigint);';
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.addCheckbox: Connection lost\n$e');
    }
  }

  Future<void> addImage(String database, username, password, json) async {
    try {
      var idSheet = json['id_sheet'];
      var imgPreview = jsonEncode({'img_preview': json['img_preview']});
      var imgRaw = jsonEncode({'img_raw': json['img_raw']});
      var request = "CALL add_image($idSheet::bigint, '$imgPreview'::text"
          ", '$imgRaw'::text);";
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.addImage: Connection lost\n$e');
    }
  }

  Future<void> addText(String database, username, password, json) async {
    try {
      var idSheet = json['id_sheet'], type = json['txt_type'];
      var request = 'CALL add_text($idSheet::bigint, $type::integer);';
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.add_text: Connection lost\n$e');
    }
  }

  /// DELETE ///

  Future<void> deleteCell(String database, username, password, json) async {
    try {
      var idCell = json['id'];
      var request = 'CALL delete_cell($idCell::bigint);';
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.deleteCell: Connection lost\n$e');
    }
  }

  Future<void> deleteSheet(String database, username, password, json) async {
    try {
      var idSheet = json['id'];
      var request = 'CALL delete_sheet($idSheet::bigint);';
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.deleteSheet: Connection lost\n$e');
    }
  }

  Future<void> deleteElement(String database, username, password, json) async {
    try {
      var idElement = json['id'];
      var request = 'CALL delete_element($idElement::bigint);';
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.deleteElement:\n$e');
    }
  }

  /// UPDATE ///

  Future<void> updateCell(String database, username, password, json) async {
    try {
      var idCell = json['id_cell'],
          title = json['title'],
          subtitle = json['subtitle'];
      var request =
          "CALL update_cell($idCell::bigint, '$title'::text, '$subtitle'::text);";
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.updateCell: Connection lost\n$e');
    }
  }

  Future<void> updateSheet(String database, username, password, json) async {
    try {
      var idSheet = json['id_sheet'],
          title = json['title'],
          subtitle = json['subtitle'];
      var request =
          "CALL update_sheet($idSheet::bigint, '$title'::text, '$subtitle'::text);";
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.updateSheet: Connection lost\n$e');
    }
  }

  Future<void> updateCheckbox(String database, username, password, json) async {
    try {
      var idElem = json['id_elem'],
          isCheck = json['is_checked'],
          text = json['text'];
      var request =
          "CALL update_checkbox($idElem::bigint, $isCheck::boolean, '$text'::"
          "text);";
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException(
          '$_className.updateCheckbox: Connection lost\n$e');
    }
  }

  Future<void> updateText(String database, username, password, json) async {
    try {
      var idElem = json['id_elem'], text = json['text'];
      var request = "CALL update_text($idElem::bigint, '$text'::text);";
      await db.query(request, database, username, password);
    } catch (e) {
      throw DatabaseException('$_className.updateTexts: Connection lost\n$e');
    }
  }

  Future<void> updateSheetOrder(
      String database, username, password, json) async {
    try {
      Iterable l = jsonDecode(json['sheets']);
      var sheets = List<Sheet>.from(l.map((model) => Sheet.fromJson(model)));
      for (var i = 0; i < sheets.length; i++) {
        if (sheets[i].idOrder != i) {
          var request = 'CALL update_sheet_order(${sheets[i].id}::bigint, '
              '${sheets[i].idOrder}::int);';
          await db.query(request, database, username, password);
        }
      }
    } catch (e) {
      throw DatabaseException('$_className.updateSheetOrder:\n$e');
    }
  }

  Future<void> updateElementOrder(
      String database, username, password, json) async {
    try {
      Iterable l = jsonDecode(json['elements']);
      var elements = List<Sheet>.from(l.map((model) => Sheet.fromJson(model)));
      var ids = <int>[], orders = <int>[];
      for (var i = 0; i < elements.length; i++) {
        ids.add(elements[i].id);
        orders.add(elements[i].idOrder);
      }
      for (var i = 0; i < ids.length; i++) {
        if (orders[i] != i) {
          var request =
              'CALL update_element_order(${ids[i]}::bigint, $i::int);';
          await db.query(request, database, username, password);
        }
      }
    } catch (e) {
      throw DatabaseException('$_className.updateElementOrder:\n$e');
    }
  }
}
