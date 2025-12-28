import "dart:async";
import "dart:io";

import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart";
import "package:flutter/material.dart";
import "package:path/path.dart" as p;

@immutable
class Path {
  final String uri;
  final bool needsSafing;
  final String filename;

  Path({
    required this.uri,
    required this.needsSafing,
  }) : filename = needsSafing
           ? p.basename(Uri.decodeFull(p.basename(uri)))
           : p.basename(uri);

  Future<String?> getUrl() async {
    if (needsSafing) {
      return FFmpegKitConfig.getSafParameterForRead(uri);
    }
    return uri;
  }

  bool get sharedInto => !needsSafing;

  /// If the input file was shared into the app, a copy was made in the app's cache.
  /// That can now be deleted.
  Future<void> deleteIfNecessary() async {
    if (sharedInto) {
      print("Deleting temporary file: $uri");
      unawaited(File(uri).delete());
    }
  }

  @override
  String toString() {
    return "Path{\n"
        "\turi: $uri\n"
        "\tneedsSafing: $needsSafing\n"
        "\tfilename: $filename\n"
        "\tsharedInto: $sharedInto\n"
        "}";
  }
}
