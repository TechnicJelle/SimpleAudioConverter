class TargetFileType {
  static const String _defaultExtension = "opus";
  String extension;

  TargetFileType({this.extension = _defaultExtension});

  void reset() {
    extension = _defaultExtension;
  }

  String? getMimeType() {
    switch (extension) {
      case "opus":
        return "audio/opus";
      case "mp3":
        return "audio/mpeg";
    }

    return null;
  }

  String getAdditionalArguments({required bool voiceOptimization}) {
    switch (extension) {
      case "opus":
        return "-c:a libopus" //codec for audio streams: libopus
            "${voiceOptimization ? " -application voip " : ""}"; //https://ffmpeg.org/ffmpeg-codecs.html#libopus-1
    }

    return "";
  }
}
