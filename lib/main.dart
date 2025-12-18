import "dart:async";
import "dart:io";

import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart";
import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart";
import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_session.dart";
import "package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart";
import "package:ffmpeg_kit_flutter_new_audio/log.dart";
import "package:ffmpeg_kit_flutter_new_audio/media_information.dart";
import "package:ffmpeg_kit_flutter_new_audio/media_information_session.dart";
import "package:ffmpeg_kit_flutter_new_audio/return_code.dart";
import "package:ffmpeg_kit_flutter_new_audio/statistics.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_handler/share_handler.dart";
import "package:share_plus/share_plus.dart";

import "media_information_view.dart";
import "tech_app.dart";
import "utils.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TechApp(
      title: "Flutter Demo",
      primary: Colors.green,
      secondary: Colors.greenAccent,
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

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

  String getAdditionalArguments() {
    switch (extension) {
      case "opus":
        return "-c:a libopus"; //codec for audio streams: libopus
    }

    return "";
  }
}

class _MyHomePageState extends State<MyHomePage> {
  bool loading = false;
  PickedFileInfo? inputFileInfo;
  final TargetFileType targetFileType = TargetFileType();
  double? convertProgress;
  FFmpegSession? ffmpegSession;
  bool done = false;
  ShareParams? shared;
  String? finalSize;
  bool voiceOptimization = false;

  @override
  void initState() {
    super.initState();
    unawaited(initShareReceiving());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initShareReceiving() async {
    final handler = ShareHandlerPlatform.instance;
    final SharedMedia? media = await handler.getInitialSharedMedia();
    if (media != null) openShared(media);

    handler.sharedMediaStream.listen((SharedMedia media) {
      if (!mounted) return;
      openShared(media);
    });
    if (!mounted) return;
  }

  void openShared(SharedMedia media) {
    try {
      unawaited(openFile(Path(uri: media.attachments!.first!.path, needsSafing: false)));
    } catch (e, s) {
      if (context.mounted) {
        showErrorDialog(
          context: context,
          title: "Error opening file",
          error: e.toString(),
          stacktrace: s.toString(),
        );
      }
      return;
    }
  }

  Future<void> openFile(Path path, {bool safIfy = false}) async {
    setState(() => loading = true);

    final MediaInformationSession? session = await getMediaInfo(path);
    if (session == null) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "Error getting media information",
          error: "Could not getSafParameterForRead",
        );
      }

      setState(() => loading = false);
      return;
    }
    final MediaInformation? information = session.getMediaInformation();

    if (information == null) {
      final String state = FFmpegKitConfig.sessionStateToString(
        await session.getState(),
      );
      final ReturnCode? returnCode = await session.getReturnCode();
      final String? failStackTrace = await session.getFailStackTrace();
      final int duration = await session.getDuration();
      final String? output = await session.getOutput();
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "Error getting media information",
          error:
              "State: $state\n"
              "Return Code: $returnCode (${returnCode?.getValue()})\n"
              "Duration: $duration\n"
              "Output:\n$output",
          stacktrace: failStackTrace,
        );
      }
      setState(() => loading = false);
      return;
    }

    setState(() {
      loading = false;
      inputFileInfo = PickedFileInfo(
        path: path,
        mediaInformation: information,
      );
      targetFileType.reset();
      convertProgress = null;
      ffmpegSession = null;
      done = false;
      shared = null;
      finalSize = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final thisInputFileInfo = inputFileInfo;
    final thisTargetFileType = targetFileType;
    final thisConvertProgress = convertProgress;
    final thisFfmpegSession = ffmpegSession;
    final thisShared = shared;
    final thisFinalSize = finalSize;

    return Scaffold(
      appBar: AppBar(
        title: thisInputFileInfo == null
            ? const Text("Simple Audio Converter")
            : Tooltip(
                message: thisInputFileInfo.filename,
                child: Text(thisInputFileInfo.filename),
              ),
        actions: [
          if (thisInputFileInfo != null && thisConvertProgress == null)
            IconButton(
              onPressed: () => setState(() {
                loading = false;
                inputFileInfo = null;
                targetFileType.reset();
                convertProgress = null;
                ffmpegSession = null;
                done = false;
                voiceOptimization = false;
              }),
              icon: const Icon(Icons.clear),
              tooltip: "Clear file",
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : thisInputFileInfo == null
            ? Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final String? uri;
                    try {
                      uri = await pickFileRead();
                    } catch (e, s) {
                      if (context.mounted) {
                        showErrorDialog(
                          context: context,
                          title: "Error showing file picker",
                          error: e.toString(),
                          stacktrace: s.toString(),
                        );
                      }
                      return;
                    }
                    if (uri == null) return; // User canceled the picker
                    try {
                      unawaited(openFile(Path(uri: uri, needsSafing: true)));
                    } catch (e, s) {
                      if (context.mounted) {
                        showErrorDialog(
                          context: context,
                          title: "Error opening file",
                          error: e.toString(),
                          stacktrace: s.toString(),
                        );
                      }
                      return;
                    }
                  },
                  child: const Text("Pick File"),
                ),
              )
            : ListView(
                children: [
                  MediaInformationView(info: thisInputFileInfo.mediaInformation),
                  const SizedBox(height: 32),
                  if (thisConvertProgress == null && !done) ...[
                    Text("Filters", style: TextTheme.of(context).titleLarge),
                    CheckboxMenuButton(
                      value: voiceOptimization,
                      onChanged: (bool? value) => setState(() {
                        voiceOptimization = value ?? false;
                      }),
                      child: const Text(
                        "Reduce background noise and optimize for voice",
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text("Target", style: TextTheme.of(context).titleLarge),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: thisTargetFileType.extension,
                      items: const [
                        DropdownMenuItem(
                          value: "opus",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Opus"),
                              Text(
                                "(Best compression & quality, good compatibility)",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: "mp3",
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("MP3"),
                              Text(
                                "(Fine compression & quality, best compatibility)",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        setState(() {
                          targetFileType.extension = value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    Text("Convert", style: TextTheme.of(context).titleLarge),
                    ElevatedButton(
                      onPressed: () async {
                        final String? targetUri;
                        try {
                          targetUri = await pickFileWrite(
                            "audio.${thisTargetFileType.extension}",
                            thisTargetFileType.getMimeType(),
                          );
                        } catch (e, s) {
                          if (context.mounted) {
                            showErrorDialog(
                              context: context,
                              title: "Error showing destination picker",
                              error: e.toString(),
                              stacktrace: s.toString(),
                            );
                          }
                          return;
                        }
                        if (targetUri == null) return; // User canceled the picker
                        done = false;
                        final String? readUrl = await thisInputFileInfo.path.getUrl();
                        if (readUrl == null) {
                          if (context.mounted) {
                            showErrorDialog(
                              context: context,
                              title: "Error parsing destination file path",
                              error: "readUrl was null",
                            );
                          }
                          return;
                        }

                        final String? writeSafUrl =
                            await FFmpegKitConfig.getSafParameterForWrite(targetUri);
                        if (writeSafUrl == null) {
                          if (context.mounted) {
                            showErrorDialog(
                              context: context,
                              title: "Error parsing target file path",
                              error: "writeSafUrl was null",
                            );
                          }
                          return;
                        }

                        unawaited(
                          doTheConvert(
                            inputFileInfo: thisInputFileInfo,
                            readUrl: readUrl,
                            targetFileType: thisTargetFileType,
                            writeUrl: writeSafUrl,
                          ),
                        );
                      },
                      child: const Text("Pick Destination File"),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "or",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final String? readUrl = await thisInputFileInfo.path.getUrl();
                        if (readUrl == null) {
                          if (context.mounted) {
                            showErrorDialog(
                              context: context,
                              title: "Error parsing destination file path",
                              error: "readUrl was null",
                            );
                          }
                          return;
                        }

                        final Directory tempDir = await getTemporaryDirectory();
                        final String filename =
                            "${thisInputFileInfo.filename}.${thisTargetFileType.extension}";
                        final String targetFilePath = p.join(tempDir.path, filename);
                        final bool success = (await doTheConvert(
                          inputFileInfo: thisInputFileInfo,
                          readUrl: readUrl,
                          targetFileType: thisTargetFileType,
                          writeUrl: targetFilePath,
                        )).isValueSuccess();
                        if (!success) return;

                        final params = ShareParams(
                          text: "Share $filename",
                          files: [XFile(targetFilePath)],
                        );

                        await SharePlus.instance.share(params);
                        setState(() {
                          shared = params;
                        });
                      },
                      child: const Text("Share to App"),
                    ),
                  ],
                  if (thisConvertProgress != null || done)
                    Text("Progress", style: TextTheme.of(context).titleLarge),
                  if (thisConvertProgress != null) ...[
                    Text("Converting to ${thisTargetFileType.extension}..."),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: thisConvertProgress,
                        minHeight: 8,
                      ),
                    ),
                  ],
                  if (thisFfmpegSession != null)
                    ElevatedButton(
                      onPressed: () async {
                        await thisFfmpegSession.cancel();
                        setState(() {
                          convertProgress = null;
                          ffmpegSession = null;
                          done = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                      ),
                      child: const Text("Cancel"),
                    ),
                  if (done) ...[
                    Text(
                      "Done!",
                      style: TextTheme.of(
                        context,
                      ).titleMedium?.copyWith(color: Colors.green),
                    ),
                    Text("Converted to ${thisTargetFileType.extension}!"),
                    if (thisFinalSize != null) Text("Final size: $thisFinalSize"),
                  ],
                  if (thisShared != null)
                    ElevatedButton(
                      onPressed: () => unawaited(SharePlus.instance.share(thisShared)),
                      child: const Text("Share again"),
                    ),
                ],
              ),
      ),
    );
  }

  Future<ReturnCode> doTheConvert({
    required PickedFileInfo inputFileInfo,
    required String readUrl,
    required TargetFileType targetFileType,
    required String writeUrl,
  }) async {
    final double? duration = double.tryParse(
      inputFileInfo.mediaInformation.getDuration() ?? "",
    );
    if (duration == null) {
      if (context.mounted) {
        showErrorDialog(
          context: context,
          title: "Error parsing media duration",
          error: "duration was null",
        );
      }
      return ReturnCode(1);
    }

    setState(() {
      convertProgress = 0.0;
      ffmpegSession = null;
      done = false;
    });

    final File? arnndnModel;
    if (voiceOptimization) {
      //Source: https://github.com/richardpl/arnndn-models
      //std.rnnn is originally bundled with Xiph RNNoise implementation (https://github.com/xiph/rnnoise/blob/master/src/rnn_data.c)
      //Another good place for info: https://github.com/GregorR/rnnoise-models/tree/master
      arnndnModel = await getFileFromAssets("arnndn-models/std.rnnn");
    } else {
      arnndnModel = null;
    }

    final completer = Completer<ReturnCode>();
    final session = await FFmpegKit.executeAsync(
      '-i "$readUrl"' //input (in double quotes to handle spaces)
      "${arnndnModel == null ? "" : " -filter:a 'arnndn=model=${arnndnModel.path}:mix=1.0' "}" //apply filters to audio streams: the arnndn denoise model
      " ${targetFileType.getAdditionalArguments()} "
      " -y " //overwrite
      ' "$writeUrl"', //output
      (FFmpegSession session) async {
        print("command: ${session.getCommand()}");
        final ReturnCode? returnCode = await session.getReturnCode();
        if (returnCode?.isValueCancel() ?? false) {
          setState(() {
            convertProgress = null;
            ffmpegSession = null;
            done = false;
          });
        } else if (returnCode?.isValueSuccess() ?? false) {
          setState(() {
            convertProgress = null;
            ffmpegSession = null;
            done = true;
          });
        } else if (returnCode?.isValueError() ?? false) {
          final String? output = await session.getOutput();
          if (mounted) {
            showErrorDialog(
              context: context,
              title: "Error while converting",
              error: "Logs:",
              //ffmpeg likes to use the same line for all the progress notifications,
              // so it uses a Carriage Return to overwrite the current line.
              // This is of course not supported here, so we replace it with a newline
              stacktrace: output?.replaceAll(String.fromCharCode(13), "\n"),
            );
            setState(() {
              convertProgress = null;
              ffmpegSession = null;
              done = false;
            });
          }
        }
        final String? sizeStr = intToSize(
          (await session.getLastReceivedStatistics())?.getSize(),
        );
        setState(() => finalSize = sizeStr);
        completer.complete(returnCode);
      },
      (Log log) {
        print(log.getMessage());
      },
      (Statistics statistics) {
        setState(() {
          convertProgress = statistics.getTime() / (duration * 1000);
        });
      },
    );
    setState(() {
      ffmpegSession = session;
    });

    return completer.future;
  }

  static Future<String?> pickFileRead() async {
    try {
      return await FFmpegKitConfig.selectDocumentForRead();
    } on PlatformException catch (e) {
      if (e.code == "SELECT_CANCELLED") return null;
      rethrow;
    }
  }

  static Future<String?> pickFileWrite(String title, String? type) async {
    try {
      return await FFmpegKitConfig.selectDocumentForWrite(title, type);
    } on PlatformException catch (e) {
      if (e.code == "SELECT_CANCELLED") return null;
      rethrow;
    }
  }

  static Future<MediaInformationSession?> getMediaInfo(
    Path path, [
    int? waitTimeout,
  ]) async {
    final String? url = await path.getUrl();
    if (url == null) return null;
    final List<String> commandArguments = [
      "-hide_banner",
      ...["-v", "error"],
      ...["-print_format", "json"],
      "-show_format",
      "-show_streams",
      "-i",
      url,
    ];
    return FFprobeKit.getMediaInformationFromCommandArguments(
      commandArguments,
      waitTimeout,
    );
  }
}

void showErrorDialog({
  required BuildContext context,
  required String title,
  required String error,
  String? stacktrace,
}) {
  unawaited(
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error),
              const SizedBox(height: 8),
              if (stacktrace != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    stacktrace,
                    style: const TextStyle(color: Colors.grey, fontFamily: "monospace"),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
