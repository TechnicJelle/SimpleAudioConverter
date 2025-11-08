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
