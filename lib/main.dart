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
import "package:ffmpeg_kit_flutter_new_audio/stream_information.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:installed_apps/app_info.dart";
import "package:installed_apps/installed_apps.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_handler/share_handler.dart";
import "package:share_plus/share_plus.dart";

import "media_information_view.dart";
import "path.dart";
import "picked_file_info.dart";
import "target_file_type.dart";
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

class _MyHomePageState extends State<MyHomePage> {
  late final Directory outputDir;
  late final Directory shareOutputDir;

  bool loading = false;
  PickedFileInfo? inputFileInfo;
  final TargetFileType targetFileType = TargetFileType();
  double? convertProgress;
  FFmpegSession? ffmpegSession;
  bool done = false;
  ShareParams? sharedParams;
  String? finalSize;
  bool voiceOptimization = false;
  String? sharedWithApp;

  @override
  void initState() {
    super.initState();
    unawaited(
      getTemporaryDirectory().then((Directory tempDir) {
        outputDir = Directory(p.join(tempDir.path, "output"));
        shareOutputDir = Directory(p.join(tempDir.path, "share_plus"));
        resetOutputDirectory();
      }),
    );
    unawaited(initShareReceiving());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initShareReceiving() async {
    final handler = ShareHandlerPlatform.instance;
    final SharedMedia? media = await handler.getInitialSharedMedia();
    if (media != null) openShared(media);

    handler.sharedMediaStream.listen(openShared);
  }

  void openShared(SharedMedia media) {
    Path? path;
    try {
      path = Path(uri: media.attachments!.first!.path, sharedInto: true);
      unawaited(openFile(path));
    } catch (e, s) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "Error opening file",
          error: e.toString(),
          stacktrace: s.toString(),
        );
      }
      path?.deleteIfNecessary();
      return;
    }
  }

  Future<void> openFile(Path path, {bool safIfy = false}) async {
    setState(() => loading = true);

    resetOutputDirectory();
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
      path.deleteIfNecessary();
      return;
    }
    final MediaInformation? information = session.getMediaInformation();

    if (information == null) {
      final String state = FFmpegKitConfig.sessionStateToString(
        await session.getState(),
      );
      final ReturnCode? returnCode = await session.getReturnCode();
      final int duration = await session.getDuration();
      final String? output = await session.getOutput();
      final String? failStackTrace = await session.getFailStackTrace();
      if (mounted) {
        String? outputClean = output;
        if (output != null) {
          final regexp = RegExp(r"^\s*{*\s*(.*?)\s*}*\s*$", dotAll: true);
          final RegExpMatch? match = regexp.firstMatch(output);
          if (match != null) outputClean = match.group(1);
        }
        showErrorDialog(
          context: context,
          title: "Error getting media information",
          error:
              "The provided file is likely not a media file, so no audio can be extracted and converted from it.\n"
              "Try another file.\n\nFurther details:",
          stacktrace:
              "State: $state\n"
                      "Return Code: $returnCode (${returnCode?.getValue()})\n"
                      "Duration: $duration\n"
                      "${outputClean == null ? "" : "Output: $outputClean\n"}"
                      "${failStackTrace == null || failStackTrace.trim().isEmpty ? "" : "Stacktrace: $failStackTrace\n"}"
                  .trim(),
        );
      }
      setState(() => loading = false);
      path.deleteIfNecessary();
      return;
    }

    if (!information.getStreams().any(
      (StreamInformation streamInfo) => streamInfo.getType() == "audio",
    )) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "File does not contain any audio",
          error: "Try another file.",
        );
      }
      setState(() => loading = false);
      path.deleteIfNecessary();
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
      sharedParams = null;
      finalSize = null;
      sharedWithApp = null;
    });
  }

  void resetOutputDirectory() {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);
    if (shareOutputDir.existsSync()) {
      shareOutputDir.deleteSync(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thisInputFileInfo = inputFileInfo;
    final thisTargetFileType = targetFileType;
    final thisConvertProgress = convertProgress;
    final thisFfmpegSession = ffmpegSession;
    final thisSharedParams = sharedParams;
    final thisFinalSize = finalSize;
    final thisSharedWithApp = sharedWithApp;

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: "Simple Audio Converter",
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset("assets/AppBar_Icon.png"),
          ),
        ),
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
                resetOutputDirectory();
              }),
              icon: const Icon(Icons.clear),
              tooltip: "Clear file",
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : thisInputFileInfo == null
          ? Center(
              child: Column(
                mainAxisSize: .min,
                children: [
                  ElevatedButton(
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
                        unawaited(openFile(Path(uri: uri, sharedInto: false)));
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
                    child: const Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(Icons.file_open_outlined),
                        SizedBox(width: 4),
                        Text("Pick File"),
                      ],
                    ),
                  ),
                  const Text("or", style: TextStyle(fontWeight: .bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    "You can also share a media file from another app into\nSimple Audio Converter",
                    textAlign: .center,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                MediaInformationView(info: thisInputFileInfo),
                const SizedBox(height: 32),
                if (thisConvertProgress == null && !done) ...[
                  Text("Filters", style: TextTheme.of(context).titleLarge),
                  CheckboxListTile(
                    value: voiceOptimization,
                    onChanged: (bool? value) => setState(() {
                      voiceOptimization = value ?? false;
                    }),
                    title: const Text(
                      "Reduce background noise and optimize for voice",
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text("Target", style: TextTheme.of(context).titleLarge),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    itemHeight: 56,
                    value: thisTargetFileType.extension,
                    items: [
                      TargetFormatDropdownItem(
                        label: "Opus",
                        description: "Best compression & quality, good compatibility",
                      ),
                      TargetFormatDropdownItem(
                        label: "MP3",
                        description: "Fine compression & quality, best compatibility",
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
                        //if the input file came from SAF, the filename isn't accurate and contains a ":"
                        //in those cases, we'll hide that and just set it to audio.ext
                        //in other cases where we do have the actual filename, we use that
                        final String filename = thisInputFileInfo.filename.contains(":")
                            ? "audio.${thisTargetFileType.extension}"
                            : "${p.withoutExtension(thisInputFileInfo.filename)}.${thisTargetFileType.extension}";
                        targetUri = await pickFileWrite(
                          filename,
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
                          targetFileType: thisTargetFileType,
                          writeUrl: writeSafUrl,
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(Icons.drive_file_move),
                        SizedBox(width: 4),
                        Text("Pick Destination File"),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "or",
                      textAlign: .center,
                      style: TextStyle(fontWeight: .bold, fontSize: 15),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final String filename =
                          "${p.withoutExtension(thisInputFileInfo.filename)}.${thisTargetFileType.extension}";
                      final String targetFilePath = p.join(outputDir.path, filename);
                      final bool success = (await doTheConvert(
                        inputFileInfo: thisInputFileInfo,
                        targetFileType: thisTargetFileType,
                        writeUrl: targetFilePath,
                      )).isValueSuccess();
                      if (!success) return;

                      final params = ShareParams(
                        text: "Share $filename",
                        files: [XFile(targetFilePath)],
                      );

                      await share(params);
                      setState(() {
                        sharedParams = params;
                      });
                    },
                    child: const Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 4),
                        Text("Share to App"),
                      ],
                    ),
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
                  const SizedBox(height: 4),
                  Text(
                    "Done!",
                    style: TextTheme.of(
                      context,
                    ).titleMedium?.copyWith(color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text("Converted to ${thisTargetFileType.extension}!"),
                  const SizedBox(height: 2),
                  if (thisFinalSize != null) Text("Final size: $thisFinalSize"),
                ],
                if (thisSharedParams != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ElevatedButton(
                      onPressed: () => unawaited(share(thisSharedParams)),
                      child: const Row(
                        mainAxisSize: .min,
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 4),
                          Text("Share again"),
                        ],
                      ),
                    ),
                  ),
                if (thisSharedWithApp != null)
                  Text(
                    "Successfully shared with: $thisSharedWithApp",
                    style: TextTheme.of(context).titleMedium,
                  ),
              ],
            ),
    );
  }

  Future<void> share(ShareParams thisShared) async {
    final shareResult = await SharePlus.instance.share(thisShared);
    if (shareResult.status == ShareResultStatus.success) {
      final String sharedWith = shareResult.raw;
      final String appID = sharedWith.split("/").first;
      final AppInfo? appInfo = await InstalledApps.getAppInfo(appID);
      if (appInfo == null) return;
      setState(() => sharedWithApp = appInfo.name);
    }
  }

  Future<ReturnCode> doTheConvert({
    required PickedFileInfo inputFileInfo,
    required TargetFileType targetFileType,
    required String writeUrl,
  }) async {
    final String? readUrl = await inputFileInfo.path.getUrl();
    if (readUrl == null) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "Error parsing destination file path",
          error: "readUrl was null",
        );
      }
      return ReturnCode(1);
    }

    final double? duration = double.tryParse(
      inputFileInfo.mediaInformation.getDuration() ?? "",
    );
    if (duration == null) {
      if (mounted) {
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
      " ${targetFileType.getAdditionalArguments(
        voiceOptimization: arnndnModel != null,
      )} "
      " -y " //overwrite
      ' "$writeUrl"', //output
      /* completeCallback */ (FFmpegSession session) async {
        print("command: ${session.getCommand()}");
        final ReturnCode? returnCode = await session.getReturnCode();
        if (returnCode?.isValueCancel() ?? false) {
          setState(() {
            convertProgress = null;
            ffmpegSession = null;
            done = false;
          });
        } else if (returnCode?.isValueSuccess() ?? false) {
          inputFileInfo.path.deleteIfNecessary();
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
      /* logCallback */ (Log log) {
        print(log.getMessage());
      },
      /* statisticsCallback */ (Statistics statistics) {
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

class TargetFormatDropdownItem extends DropdownMenuItem<String> {
  /// The [DropdownMenuItem]'s `value` is derived from the [label]
  TargetFormatDropdownItem({
    required String label,
    required String description,
    super.key,
  }) : super(
         value: label.toLowerCase(),
         child: RichText(
           text: TextSpan(
             text: "$label\n",
             style: const TextStyle(height: 1.3),
             children: [
               TextSpan(
                 text: "($description)",
                 style: const TextStyle(
                   fontSize: 13,
                   fontStyle: FontStyle.italic,
                   color: Colors.grey,
                 ),
               ),
             ],
           ),
         ),
       );
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Understood"),
          ),
        ],
      ),
    ),
  );
}
