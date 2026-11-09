import 'dart:js_interop';

import 'package:web/web.dart' as web;

final _phoneLike = RegExp(r'^\+\d{9,15}$');

// Mehmon ismi formula bo'lib Excel'da ishga tushmasligi kerak.
String _cell(Object? value) {
  var text = '${value ?? ''}';
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0]) && !_phoneLike.hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

/// Excel ochadigan CSV (BOM va CRLF bilan) yuklab beradi.
void downloadCsv(String filename, List<List<Object?>> rows) {
  final csv = '﻿${rows.map((row) => row.map(_cell).join(';')).join('\r\n')}';
  final blob = web.Blob([csv.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}
