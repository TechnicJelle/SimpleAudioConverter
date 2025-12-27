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

  @override
  String toString() {
    return "Path{\n"
        "\turi: $uri\n"
        "\tneedsSafing: $needsSafing\n"
        "\tfilename: $filename\n"
        "}";
  }
}
