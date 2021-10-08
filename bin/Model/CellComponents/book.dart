import '../Elements/element.dart';
import '../sheet.dart';
import '../cell.dart';

class Book extends Cell{
  int sheetSelect = 0;

  Book(int id, String title, String subtitle)
      : super(id: id, title: title, subtitle: subtitle, type: (Book).toString());

  Book.fromJson(Map<String, dynamic> json)
      : super(id: json['id'], title: json['title'], subtitle: json['subtitle'], type: (Book).toString());

  void removeSheetAt(int index){
    sheets.removeAt(index);
    //if(sheets.isEmpty)
    //  sheets.add(Sheet("New sheet", [Texts(text:"Title", type: TextType.title, id: null, idOrder: null)]));
  }

  void modifySheet(Sheet sheet) => sheets[sheetSelect] = sheet;

  Sheet getSheetAt(int index){
    sheetSelect = index;
    return sheets[sheetSelect];
  }

  ///Sheet content manager
  void addElement(Element elem) => sheets[sheetSelect].addElement(elem);

  void removeSheetContent(int indexContent) => sheets[sheetSelect].elements.removeAt(indexContent);

  bool isValidSheetTitle(String title) {
    for(var i = 0; i < sheets.length; i++){
      if(sheets[i].title == title) {
        return false;
      }
    }
    return true;
  }

  @override
  void addElements(List<Element> list) => sheets[sheetSelect].elements = list;

  @override
  void sortElements() => sheets.forEach((element) => element.sort());
}