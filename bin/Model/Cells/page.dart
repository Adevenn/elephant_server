import '../Elements/element_custom.dart';

/// int id,
///
/// int idParent,
///
/// String title,
///
/// String subtitle,
///
/// List elements,
///
/// int idOrder
class Page{
  final int id;
  final int idParent;
  String title;
  String subtitle;
  List<ElementCustom> elements = [];
  int get elemCount => elements.length;
  int idOrder;

  Page(this.id, this.idParent, this.title, this.subtitle, this.idOrder);

  Page.fromJson(Map<String, dynamic> json)
      : id = json['id_sheet'],
        idParent = json['id_cell'],
        title = json['title'],
        subtitle = json['subtitle'],
        idOrder = json['sheet_order'];

  Map<String, dynamic> toJson() => {
    'id_sheet' : id,
    'id_cell' : idParent,
    'title' : title,
    'subtitle' : subtitle,
    'sheet_order' : idOrder,
  };
}