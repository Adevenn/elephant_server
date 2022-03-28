import 'dart:convert';
import 'dart:typed_data';

import 'checkbox.dart';
import 'image.dart';
import 'text.dart';
import 'text_type.dart';

abstract class Element {
  final int id;
  final int idParent;
  int idOrder;

  Element({required this.id, required this.idParent, required this.idOrder});

  factory Element.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'Checkbox':
        return Checkbox(
            id: json['id'],
            idParent: json['id_sheet'],
            isChecked: json['is_checked'],
            text: json['text'],
            idOrder: json['elem_order']);
      case 'Image':
        var imgPreview = jsonDecode(json['image_preview']);
        return Image(
            id: json['id'],
            idParent: json['id_sheet'],
            imgPreview:
                Uint8List.fromList(imgPreview['img_preview'].cast<int>()),
            imgRaw: Uint8List(0),
            idOrder: json['elem_order']);
      case 'Text':
        return Text(
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
