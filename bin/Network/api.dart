import 'dart:async';
import 'dart:convert';

import '../Exception/database_exception.dart';
import '../Model/Cells/cell.dart';
import '../Model/Elements/element_custom.dart';
import '../Model/Cells/page.dart';
import 'data_db.dart';

class API {
  final String _className = 'API';
  late final DB db;

  API(String username, String password) {
    db = DB(username: username, password: password);
  }

  ///Select cells from database that match with [matchWord]
  Future<List<Cell>> selectCells(String username, Map json) async {
    try {
      var matchWord = json['match_word'];
      var request = "select * from cell where title LIKE '%$matchWord%' AND "
          "author = '$username' OR is_public = true ORDER BY title;";
      var result = await db.queryWithResult(request);

      var cells = <Cell>[];
      for (final row in result) {
        cells.add(Cell.fromJson(row['cell']));
      }
      return cells;
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectCells:\n$e');
    }
  }

  ///Select pages from database that match with [id_cell]
  Future<List<Page>> selectPages(Map json) async {
    try {
      var idCell = json['id_cell'];
      var request = 'SELECT * FROM sheet WHERE '
          'id_cell = $idCell ORDER BY sheet_order;';
      var result = await db.queryWithResult(request);

      var pages = <Page>[];
      for (final row in result) {
        pages.add(Page.fromJson(row['sheet']));
      }
      return pages;
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectPages\n$e');
    }
  }

  ///Select sheet from database that match with [id_cell] and [sheet_index]
  Future<Page> selectPage(Map json) async {
    try {
      var idCell = json['id_cell'], pageIndex = json['sheet_index'];
      var request = 'SELECT * FROM sheet WHERE id_cell = $idCell AND '
          'sheet_order = $pageIndex;';
      var result = await db.queryWithResult(request);
      return Page.fromJson(result[0]['sheet']);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectPage\n$e');
    }
  }

  ///Select elements from database that match with [id_sheet]
  Future<List<ElementCustom>> selectElements(Map json) async {
    try {
      var idSheet = json['id_sheet'];
      var request = 'select * from get_elements($idSheet::bigint);';
      var result = await db.queryWithResult(request);

      var elems = <ElementCustom>[];
      for (final row in result) {
        elems.add(ElementCustom.fromJson(row['']));
      }
      return elems;
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.selectElements:\n$e');
    }
  }

  ///Select image from database that match with [id_img]
  Future<Map> selectRawImage(Map json) async {
    try {
      var idImg = json['id_img'];
      var request = 'SELECT image_raw FROM image WHERE id = $idImg;';
      var rawImg = await db.queryWithResult(request);
      return rawImg[0]['image'];
    } catch (e) {
      throw Exception('$_className.selectRawImage:\n$e');
    }
  }

  Future<void> addCell(Map json) async {
    try {
      var title = json['title'],
          subtitle = json['subtitle'],
          type = json['type'],
          author = json['author'],
          isPublic = json['is_public'];
      var request = "CALL add_cell('$title', '$subtitle', '$type', '$author', $isPublic::boolean);";
      await db.query(request);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.addCell:\n$e');
    }
  }

  Future<void> addPage(Map json) async {
    try {
      var idCell = json['id_cell'];
      var request = 'select add_page($idCell::bigint);';
      await db.query(request);
    } on DatabaseException catch (e) {
      throw DatabaseException('$_className.addPage: Wrong entries\n$e');
    } catch (e) {
      throw DatabaseException('$_className.addPage: Connection lost\n$e');
    }
  }

  Future<void> addCheckbox(Map json) async {
    try {
      var idPage = json['id_sheet'];
      var request = 'CALL add_checkbox($idPage::bigint);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.addCheckbox: Connection lost\n$e');
    }
  }

  Future<void> addImage(Map json) async {
    try {
      var idPage = json['id_sheet'];
      //Postgresql needs '{' and '}' to to delimit an array
      var preview = json['img_preview'].toString().replaceAll('[', '{').replaceAll(']', '}');
      var raw = json['img_raw'].toString().replaceAll('[', '{').replaceAll(']', '}');
      var request = "CALL add_image($idPage, '$preview', '$raw');";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.addImage: Connection lost\n$e');
    }
  }

  Future<void> addText(Map json) async {
    try {
      var idPage = json['id_sheet'], type = json['txt_type'];
      var request = 'CALL add_text($idPage::bigint, $type::integer);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.addText: Connection lost\n$e');
    }
  }

  Future<void> addFlashcard(Map json) async {
    try {
      var idPage = json['id_sheet'];
      var request = 'CALL add_flashcard($idPage::bigint);';
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.addFlashcard: Connection lost\n$e');
    }
  }

  Future<void> delete(Map json) async {
    try {
      var id = json['id'];
      var type = json['item_type'];
      var request = "CALL delete($id::bigint, '$type'::text);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.delete: Connection lost\n$e');
    }
  }

  Future<void> updateCell(Map json) async {
    try {
      var idCell = json['id_cell'],
          title = json['title'],
          subtitle = json['subtitle'],
          author = json['author'],
          isPublic = json['is_public'];
      var request =
          "CALL update_cell($idCell::bigint, '$title'::text, '$subtitle'::text, '$author'::text, $isPublic::boolean);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.updateCell: Connection lost\n$e');
    }
  }

  Future<void> updatePage(Map json) async {
    try {
      var idPage = json['id_sheet'], title = json['title'], subtitle = json['subtitle'];
      var request = "CALL update_sheet($idPage::bigint, '$title'::text, '$subtitle'::text);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.updatePage: Connection lost\n$e');
    }
  }

  Future<void> updateCheckbox(Map json) async {
    try {
      var idElem = json['id'], isCheck = json['is_checked'], text = json['cb_text'];
      var request = "CALL update_checkbox($idElem::bigint, $isCheck::boolean, '$text'::"
          'text);';
      await db.query(request);
    } catch (e) {
      print('ERROR UPDATE CB : $e');
      throw DatabaseException('$_className.updateCheckbox: Connection lost\n$e');
    }
  }

  Future<void> updateText(Map json) async {
    try {
      var idElem = json['id'], text = json['txt_text'];
      var request = "CALL update_text($idElem::bigint, '$text'::text);";
      await db.query(request);
    } catch (e) {
      throw DatabaseException('$_className.updateTexts: Connection lost\n$e');
    }
  }

  Future<void> updatePageOrder(Map json) async {
    try {
      var pages = List<Page>.from(json['page_order'].map((page) => Page.fromJson(jsonDecode(page))));
      for (var i = 0; i < pages.length; i++) {
        if (pages[i].idOrder != i) {
          var request = 'CALL update_sheet_order(${pages[i].id}::bigint, $i::int);';
          await db.query(request);
        }
      }
    } catch (e) {
      throw DatabaseException('$_className.updatePageOrder:\n$e');
    }
  }

  Future<void> updateElementOrder(Map json) async {
    try {
      var elements = List<ElementCustom>.from(json['elem_order'].map((elem) => ElementCustom.fromJson(jsonDecode(elem))));
      for (var i = 0; i < elements.length; i++) {
        if (elements[i].idOrder != i) {
          var request = 'CALL update_element_order(${elements[i].id}::bigint, $i::int);';
          await db.query(request);
        }
      }
    } catch (e) {
      throw DatabaseException('$_className.updateElementOrder:\n$e');
    }
  }
}
