import 'element_custom.dart';

class ImageCustom extends ElementCustom {
  List<int> imgPreview, imgRaw;

  ImageCustom(
      {required int id,
      required int idParent,
      required this.imgPreview,
      required this.imgRaw,
      required int idOrder})
      : super(id: id, idSheet: idParent, idOrder: idOrder);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'id_sheet': idSheet,
        'img_preview': imgPreview,
        'img_raw': imgRaw,
        'elem_order': idOrder,
        'elem_type': runtimeType.toString(),
      };
}
