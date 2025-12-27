import "package:ffmpeg_kit_flutter_new_audio/media_information.dart";
import "package:flutter/material.dart";

import "path.dart";

@immutable
class PickedFileInfo {
  final Path path;
  final MediaInformation mediaInformation;

  const PickedFileInfo({
    required this.path,
    required this.mediaInformation,
  });

  String get filename => path.filename;
}
