import '../Elements/CheckBox.dart';
import '../Elements/Element.dart';
import '../Sheet.dart';

import '../Cell.dart';

class ToDoList extends Cell{

  ToDoList({required int id, required String title, String subtitle = ''})
      : super(id: id, title: title, subtitle: subtitle, type: (ToDoList).toString()){
    //if(content.isEmpty)
    //content.add(CheckBox(text: ""));
  }

  ToDoList.fromJson(Map<String, dynamic> json)
      : super(id: json['id'], title: json['title'], subtitle: json['subtitle'], type: (ToDoList).toString());

  @override
  void addElements(List<Element> list) => sheets[0].elements = list;

  @override
  void sortElements() => sheets[0].sort();

  @override
  void addSheets(List<Sheet> list) {
    throw Exception("ToDoList can't contain multiple sheet");
  }
}