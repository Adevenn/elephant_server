import 'dart:async';
import 'dart:convert';

import '../Exception/database_exception.dart';
import '../Model/cell.dart';
import '../Model/Elements/element.dart';
import '../Model/Cells/Book/sheet.dart';
import 'data_db.dart';

class API {
  final String _className = 'API';
  late final DB db;

  API(String username, String password) {
    db = DB(username: username, password: password);
  }

  ///DB values -> List<Cell>
  List<Cell> _resultToCells(List<dynamic> result) {
    try {
      var cells = <Cell>[];
      for (final row in result) {
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

  /// SELECT ///

  ///Select cells from database that match with [matchWord]
  Future<List<Cell>> selectCells(String username, Map json) async {
    try {
      print('username : $username');
      var matchWord = json['match_word'];
      var request = "select * from cell where title LIKE '%$matchWord%' AND "
          "author = '$username' OR is_public = true ORDER BY title;";
      var result = await db.queryWithResult(request);
      return _resultToCells(result);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectCells:\n$e');
    }
  }

  ///Select sheets from database that match with [id_cell]
  Future<List<Sheet>> selectSheets(Map json) async {
    try {
      var idCell = json['id_cell'];
      var request = 'SELECT * FROM sheet WHERE '
          'id_cell = $idCell ORDER BY sheet_order;';
      var result = await db.queryWithResult(request);
      return _resultToSheets(result);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectSheets\n$e');
    }
  }

  ///Select sheet from database that match with [id_cell] and [sheet_index]
  Future<Sheet> selectSheet(Map json) async {
    try {
      var idCell = json['id_cell'], sheetIndex = json['sheet_index'];
      var request = 'SELECT * FROM sheet WHERE id_cell = $idCell AND '
          'sheet_order = $sheetIndex;';
      var result = await db.queryWithResult(request);
      print(result);
      return Sheet.fromJson(result[0]['sheet']);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectSheet\n$e');
    }
  }

  ///Select elements from database that match with [id_sheet]
  Future<List<Element>> selectElements(Map json) async {
    try {
      var idSheet = json['id_sheet'];
      List<dynamic> cb, img, txt;
      var requestCb = 'SELECT * FROM checkbox '
          'WHERE id_sheet = $idSheet ORDER BY elem_order;';
      cb = await db.queryWithResult(requestCb);

      var requestImg = 'SELECT * FROM image WHERE '
          'id_sheet = $idSheet ORDER BY elem_order;';
      img = await db.queryWithResult(requestImg);

      var requestTxt = 'SELECT * FROM text WHERE '
          'id_sheet = $idSheet ORDER BY elem_order;';
      txt = await db.queryWithResult(requestTxt);

      var elems = cb + img + txt;
      return _resultToElems(elems, idSheet);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectElements:\n$e');
    }
  }

  ///Select image from database that match with [id_img]
  Future<String> selectRawImage(Map json) async {
    try {
      var idImg = json['id_img'];
      var request = 'SELECT image_raw FROM image WHERE id = $idImg;';
      var rawImg = await db.queryWithResult(request);
      return rawImg[0]['image']['image_raw'];
    } catch (e) {
      throw Exception('$_className.selectRawImage:\n$e');
    }
  }

  /// ADD ///

  Future<void> addCell(Map json) async {
    try {
      var title = json['title'],
          subtitle = json['subtitle'],
          type = json['type'],
          author = json['author'],
          isPublic = json['is_public'];
      var request =
          "CALL add_cell('$title', '$subtitle', '$type', '$author', $isPublic::boolean);";
      await db.query(request);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.addCell:\n$e');
    }
  }

  Future<void> addSheet(Map json) async {
    try {
      var idCell = json['id_cell'],
          title = json['title'],
          subtitle = json['subtitle'];
      var request =
          "select add_sheet($idCell::bigint, '$title'::text, '$subtitle'::text);";
      await db.query(request);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.addSheet: Wrong entries\n$e');
    } catch (e) {
      throw DatabaseException('$_className.addSheet: Connection lost\n$e');
    }
  }

  Future<void> addCheckbox(Map json) async {
    try {
      var idSheet = json['id_sheet'];
      var request = 'CALL add_checkbox($idSheet::bigint);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.addCheckbox: Connection lost\n$e');
    }
  }

  Future<void> addImage(Map json) async {
    try {
      var idSheet = json['id_sheet'];
      var imgPreview = jsonEncode({'img_preview': json['img_preview']});
      var imgRaw = jsonEncode({'img_raw': json['img_raw']});
      var request = "CALL add_image($idSheet::bigint, '$imgPreview'::text"
          ", '$imgRaw'::text);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.addImage: Connection lost\n$e');
    }
  }

  Future<void> addText(Map json) async {
    try {
      var idSheet = json['id_sheet'], type = json['txt_type'];
      var request = 'CALL add_text($idSheet::bigint, $type::integer);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.add_text: Connection lost\n$e');
    }
  }

  /// DELETE ///

  Future<void> deleteCell(Map json) async {
    try {
      var idCell = json['id'];
      var request = 'CALL delete_cell($idCell::bigint);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.deleteCell: Connection lost\n$e');
    }
  }

  Future<void> deleteSheet(Map json) async {
    try {
      var idSheet = json['id'];
      print(idSheet);
      var request = 'CALL delete_sheet($idSheet::bigint);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.deleteSheet: Connection lost\n$e');
    }
  }

  Future<void> deleteElement(Map json) async {
    try {
      var idElement = json['id'];
      var request = 'CALL delete_element($idElement::bigint);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.deleteElement:\n$e');
    }
  }

  /// UPDATE ///

  Future<void> updateCell(Map json) async {
    try {
      var idCell = json['id_cell'],
          title = json['title'],
          subtitle = json['subtitle'],
          author = json['author'],
          isPublic = json['is_public'];
      var request =
          "CALL update_cell($idCell::bigint, '$title'::text, '$subtitle'::tex"
          "t), '$author'::text, $isPublic::boolean;";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.updateCell: Connection lost\n$e');
    }
  }

  Future<void> updateSheet(Map json) async {
    try {
      var idSheet = json['id_sheet'],
          title = json['title'],
          subtitle = json['subtitle'];
      var request =
          "CALL update_sheet($idSheet::bigint, '$title'::text, '$subtitle'::text);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.updateSheet: Connection lost\n$e');
    }
  }

  Future<void> updateCheckbox(Map json) async {
    try {
      var idElem = json['id'],
          isCheck = json['is_checked'],
          text = json['text'];
      var request =
          "CALL update_checkbox($idElem::bigint, $isCheck::boolean, '$text'::"
          "text);";
      await db.query(request);
    } catch (e) {
      print('ERROR UPDATE CB : $e');
      throw DatabaseException(
          '$_className.updateCheckbox: Connection lost\n$e');
    }
  }

  Future<void> updateText(Map json) async {
    try {
      var idElem = json['id'], text = json['text'];
      var request = "CALL update_text($idElem::bigint, '$text'::text);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.updateTexts: Connection lost\n$e');
    }
  }

  Future<void> updateSheetOrder(Map json) async {
    try {
      var sheets = List<Sheet>.from(json['sheet_order']
          .map((model) => Sheet.fromJson(jsonDecode(model))));
      for (var i = 0; i < sheets.length; i++) {
        if (sheets[i].idOrder != i) {
          var request = 'CALL update_sheet_order(${sheets[i].id}::bigint, '
              '${sheets[i].idOrder}::int);';
          await db.query(request);
        }
      }
    } catch (e) {
      throw DatabaseException('$_className.updateSheetOrder:\n$e');
    }
  }

  Future<void> updateElementOrder(Map json) async {
    try {
      var elements = List<Element>.from(json['elem_order']
          .map((model) => Element.fromJson(jsonDecode(model))));
      var ids = <int>[], orders = <int>[];
      for (var i = 0; i < elements.length; i++) {
        ids.add(elements[i].id);
        orders.add(elements[i].idOrder);
      }
      for (var i = 0; i < ids.length; i++) {
        if (orders[i] != i) {
          var request =
              'CALL update_element_order(${ids[i]}::bigint, $i::int);';
          await db.query(request);
        }
      }
    } catch (e) {
      throw DatabaseException('$_className.updateElementOrder:\n$e');
    }
  }
}
