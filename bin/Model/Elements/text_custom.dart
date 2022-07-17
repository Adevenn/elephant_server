import 'element_custom.dart';
import 'text_type.dart';

class TextCustom extends ElementCustom {
  String text;
  late TextType txtType;

  TextCustom(
      {required this.text,
      required this.txtType,
      required int id,
      required int idParent,
      required int idOrder})
      : super(id: id, idSheet: idParent, idOrder: idOrder);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'id_sheet': idSheet,
        'txt_text': text,
        'txt_type': txtType.index,
        'elem_order': idOrder,
        'elem_type': runtimeType.toString(),
      };
}