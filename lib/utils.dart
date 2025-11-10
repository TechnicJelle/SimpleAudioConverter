import "package:flutter/material.dart";

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
