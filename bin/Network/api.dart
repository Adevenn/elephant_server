import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../Exception/database_exception.dart';
import '../Exception/server_exception.dart';
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
import 'database.dart';

class API {
  final _className = 'API';
  late final DB db;

  API(String ip, int port) {
    db = DB(ip, port);
  }

  List<Element> sortElems(List<Element> elements) {
    for (var i = 1; i < elements.length; i++) {
      if (elements[i].idOrder < elements[i - 1].idOrder) {
        var elem = elements[i];
        elements[i] = elements[i - 1];
        elements[i - 1] = elem;
        i = 0;
      }
    }
    return elements;
  }

  Future<void> test(String database, username, password) async {
    try {
      await db.test(database, username, password);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.test:\n$e');
    }
  }

  /// SELECT ///

  List<Cell> _resultToCells(List<dynamic> result) {
    try {
      var cells = <Cell>[];
      for (final row in result) {
        var id = row['cell']['id'] as int;
        var title = row['cell']['title'] as String;
        var subtitle = row['cell']['subtitle'] as String;
        switch (row['cell']['type'] as int) {
          case 0:
            cells.add(Book(id, title, subtitle));
            break;
          case 1:
            cells.add(ToDoList(id: id, title: title, subtitle: subtitle));
            break;
          case 2:
            cells.add(Ranking(id: id, title: title, subtitle: subtitle));
            break;
          default:
            throw DatabaseException('Not an existing type of cell');
        }
      }
      return cells;
    } catch (e) {
      throw DatabaseException('$e');
    }
  }

  List<Sheet> _resultToSheets(List<dynamic> result) {
    var sheets = [];
    var sheetsRaw = [];
    var idCell = 0;
    for (var i = 0; i < sheetsRaw.length; i++) {
      var sheet = Sheet(
          sheetsRaw[i][0] as int,
          idCell,
          sheetsRaw[i][1] as String,
          sheetsRaw[i][2] as String,
          sheetsRaw[i][3] as int);
      sheets.add(sheet);
    }
    //return sheets;
    return [];
  }

  List<Element> _resultToElems(List<dynamic> cb, img, txt, int idSheet) {
    var elems = <Element>[];
    //Extract data from db values and create objects
    for (final elem in cb) {
      elems.add(Checkbox(
          id: elem[0] as int,
          idParent: idSheet,
          text: elem[1] as String,
          isChecked: elem[2] as bool,
          idOrder: elem[3] as int));
    }
    for (final elem in img) {
      var data = jsonDecode(elem[1]);
      elems.add(Image(
          id: elem[0] as int,
          idParent: idSheet,
          imgPreview: Uint8List.fromList(data['img_preview'].cast<int>()),
          imgRaw: Uint8List(0),
          idOrder: elem[2] as int));
    }
    for (final elem in txt) {
      elems.add(Text(
          id: elem[0] as int,
          idParent: idSheet,
          text: elem[1] as String,
          txtType: TextType.values[elem[2] as int],
          idOrder: elem[3] as int));
    }

    if (elems.length > 1) {
      elems = sortElems(elems);
    }

    for (var i = 1; i < elems.length; i++) {
      if (elems[i].idOrder < elems[i - 1].idOrder) {
        var elem = elems[i];
        elems[i] = elems[i - 1];
        elems[i - 1] = elem;
        i = 0;
      }
    }
    return elems;
  }

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

  Future<List<Sheet>> selectSheets(
      String database, username, password, json) async {
    try {
      var idCell = json['id_cell'];
      var request = 'SELECT id, title, subtitle, idorder FROM sheet WHERE '
          'idcell = $idCell ORDER BY idorder;';
      var result =
          await db.queryWithResult(request, database, username, password);
      return _resultToSheets(result);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectSheets\n$e');
    }
  }

  Future<Sheet> selectSheet(String database, username, password, json) async {
    try {
      var idCell = json['id_cell'], sheetIndex = json['sheet_index'];
      var request = 'SELECT id, title, subtitle FROM '
          'sheet WHERE idcell = $idCell AND idorder = '
          '$sheetIndex;';
      var result =
          await db.queryWithResult(request, database, username, password);
      return Sheet(result[0][0] as int, idCell, result[0][1] as String,
          result[0][2] as String, sheetIndex);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectSheet\n$e');
    }
  }

  Future<List<Element>> selectElements(
      String database, username, password, json) async {
    try {
      var idSheet = json['id_sheet'];
      List<dynamic> cb, img, txt;
      var requestCb = 'SELECT id, text, is_checked, elem_order FROM checkbox '
          'WHERE id_sheet = $idSheet ORDER BY elem_order;';
      cb = await db.queryWithResult(requestCb, database, username, password);
      var requestImg = 'SELECT id, image_preview, elem_order FROM image WHERE '
          'id_sheet = $idSheet ORDER BY elem_order;';
      img = await db.queryWithResult(requestImg, database, username, password);
      var requestTxt = 'SELECT id, text, type, elem_order FROM text WHERE '
          'id_sheet = $idSheet ORDER BY elem_order;';
      txt = await db.queryWithResult(requestTxt, database, username, password);
      return _resultToElems(cb, img, txt, idSheet);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectElements:\n$e');
    }
  }

  Future<String> selectRawImage(
      String database, username, password, json) async {
    try {
      var idImg = json['id_img'];
      var request = 'SELECT image_raw FROM image WHERE id = $idImg;';
      var rawImgResult =
          await db.queryWithResult(request, database, username, password);
      for (final rawImg in rawImgResult) {
        return rawImg[0] as String;
      }
      throw Exception('No rawImage found with id : $idImg');
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
      int typeInt;
      switch (type) {
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
      var request = "CALL add_cell('$title'::text, '$subtitle'::text, "
          "$typeInt::integer);";
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
          "CALL add_sheet($idCell::bigint, '$title'::text, '$subtitle'::text);";
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
