class TargetFileType {
  static const String _defaultExtension = "opus";
  String extension;

  new({this.extension = _defaultExtension});

  void reset() {
    extension = _defaultExtension;
  }

  String? getMimeType() => switch (extension) {
    "opus" => "audio/opus",
    "mp3" => "audio/mpeg",
    _ => null,
  };

  String getAdditionalArguments({required bool voiceOptimization}) =>
      switch (extension) {
        "opus" =>
          "-c:a libopus" //codec for audio streams: libopus
              "${voiceOptimization ? " -application voip " : ""}", //https://ffmpeg.org/ffmpeg-codecs.html#libopus-1
        _ => "",
      };
}
