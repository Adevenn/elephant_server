import '../Model/CellComponents/Ranking.dart';
import '../Model/CellComponents/ToDoList.dart';

import 'CellComponents/Book.dart';
import 'Elements/Element.dart';
import 'Sheet.dart';

abstract class Cell{
  final int id;
  String title;
  String subtitle;
  List<Sheet> sheets = [];
  final String type;


  Cell({required this.id, required this.title, required this.subtitle, required this.type});

  factory Cell.factory({required int id, required String title, required String subtitle, required String type}){
    switch(type){
      case 'Book':
        return Book(id, title, subtitle);
      case 'ToDoList':
        return ToDoList(id: id, title: title);
      case 'Ranking':
        return Ranking(id: id, title: title);
      default:
        throw Exception('Json with wrong cell type');
    }
  }

  factory Cell.fromJson(Map<String, dynamic> json){
    switch(json['type']){
      case 'Book':
        return Book.fromJson(json);
      case 'ToDoList':
        return ToDoList.fromJson(json);
      case 'Ranking':
        return Ranking.fromJson(json);
      default:
        throw Exception('Wrong cell type');
    }
  }

  Map<String, dynamic> toJson() => {
    'id' : id,
    'title' : title,
    'subtitle' : subtitle,
    'type' : type,
  };

  void addSheets(List<Sheet> list) => sheets = list;
  void addElements(List<Element> list);
  void sortElements();
}