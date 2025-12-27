import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";

/// For Table Rows
List<Widget> tr(
  String type,
  String? content,
  BuildContext context, {
  bool inRow = false,
}) {
  return [
    Text(type, style: TextTheme.of(context).titleSmall),
    if (inRow) Flexible(child: nText(content)) else nText(content),
  ];
}

/// Nullable Text Widget
///
/// Says "Unknown" in italic grey if [str] is null.
Text nText(String? str) {
  if (str == null) {
    return const Text(
      "Unknown",
      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
    );
  } else {
    return Text(str);
  }
}

String? strToSize(String? sizeStr) {
  final int? sizeNum = int.tryParse(sizeStr ?? "");
  return intToSize(sizeNum);
}

String? intToSize(int? sizeNum) {
  return sizeNum == null ? null : "${(sizeNum / 1e+6).toStringAsFixed(2)} MB";
}

Future<File> getFileFromAssets(String path) async {
  final Directory tempDir = await getTemporaryDirectory();
  final String tempPath = tempDir.path;
  final String filePath = "$tempPath/$path";
  final File file = File(filePath);
  if (file.existsSync()) {
    return file;
  } else {
    final byteData = await rootBundle.load("assets/$path");
    final buffer = byteData.buffer;
    await file.create(recursive: true);
    return file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
  }
}
