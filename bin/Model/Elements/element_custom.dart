import 'dart:convert';
import 'dart:typed_data';

import 'checkbox_custom.dart';
import 'image_custom.dart';
import 'text_custom.dart';
import 'text_type.dart';

abstract class ElementCustom {
  final int id;
  final int idParent;
  int idOrder;

  ElementCustom({required this.id, required this.idParent, required this.idOrder});

  factory ElementCustom.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'CheckboxCustom':
        return CheckboxCustom(
            id: json['id'],
            idParent: json['id_sheet'],
            isChecked: json['is_checked'],
            text: json['text'],
            idOrder: json['elem_order']);
      case 'ImageCustom':
        var imgPreview = jsonDecode(json['image_preview']);
        return ImageCustom(
            id: json['id'],
            idParent: json['id_sheet'],
            imgPreview:
                Uint8List.fromList(imgPreview['img_preview'].cast<int>()),
            imgRaw: Uint8List(0),
            idOrder: json['elem_order']);
      case 'TextCustom':
        return TextCustom(
            id: json['id'],
            idParent: json['id_sheet'],
            text: json['text'],
            txtType: TextType.values[json['txt_type']],
            idOrder: json['elem_order']);
      default:
        throw Exception('Json with wrong element type\n$json');
    }
  }

  Map<String, dynamic> toJson();
}
