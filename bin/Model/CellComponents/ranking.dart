import '../sheet.dart';

import '../cell.dart';

class Ranking extends Cell{

  Ranking({required int id, required String title, String subtitle = ''})
      : super(id: id, title: title, subtitle: subtitle, type: (Ranking).toString());

  Ranking.fromJson(Map<String, dynamic> json)
      : super(id: json['id'], title: json['title'], subtitle: json['subtitle'], type: (Ranking).toString());

  @override
  void addElements(List<Object> list) {
    // TODO: implement addContent
    throw UnimplementedError();
  }

  @override
  void sortElements() {
    // TODO: implement sortElements
    throw UnimplementedError();
  }

  @override
  void addSheets(List<Sheet> list) {
    // TODO: implement addSheets
    throw UnimplementedError();
  }
}