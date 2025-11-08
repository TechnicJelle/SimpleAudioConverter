import "dart:async";

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

import "media_information_view.dart";
import "tech_app.dart";

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
class PickedFileInfo {
  final String uri;
  final String filename;
  final MediaInformation mediaInformation;

  PickedFileInfo({
    required this.uri,
    required this.mediaInformation,
  }) : filename = p.basename(Uri.decodeFull(p.basename(uri)));
}

class _MyHomePageState extends State<MyHomePage> {
  bool loading = false;
  PickedFileInfo? inputFileInfo;
  String? targetUri;
  double? convertProgress;
  bool done = false;

  Future<void> openFile(String uri) async {
    setState(() => loading = true);

    final MediaInformationSession? session = await getMediaInfo(uri);
    if (session == null) {
      //TODO: Show error in a proper way
      setState(() => loading = false);
      return;
    }
    final MediaInformation? information = session.getMediaInformation();

    if (information == null) {
      final String state = FFmpegKitConfig.sessionStateToString(
        await session.getState(),
      );
      print(state);
      final ReturnCode? returnCode = await session.getReturnCode();
      print(returnCode);
      final String? failStackTrace = await session.getFailStackTrace();
      print(failStackTrace);
      final int duration = await session.getDuration();
      print(duration);
      final String? output = await session.getOutput();
      print(output);
      //TODO: Show error in a proper way
      setState(() => loading = false);
      return;
    }

    setState(() {
      loading = false;
      inputFileInfo = PickedFileInfo(
        uri: uri,
        mediaInformation: information,
      );
      targetUri = null;
      convertProgress = null;
      done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final thisInputFileInfo = inputFileInfo;
    final thisTargetUri = targetUri;
    final thisConvertProgress = convertProgress;

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
                targetUri = null;
                convertProgress = null;
                done = false;
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
              child: ElevatedButton(
                onPressed: () async {
                  final String? uri = await pickFileRead();
                  if (uri == null) return; // User canceled the picker
                  unawaited(openFile(uri));
                },
                child: const Text("Pick File"),
              ),
            )
          : ListView(
              children: [
                MediaInformationView(info: thisInputFileInfo.mediaInformation),
                Text("Destination:", style: TextTheme.of(context).titleLarge),
                if (thisTargetUri == null)
                  ElevatedButton(
                    onPressed: () async {
                      final uri = await pickFileWrite("audio.opus", "audio/opus");
                      if (uri == null) return; // User canceled the picker
                      setState(() {
                        targetUri = uri;
                        done = false;
                      });
                    },
                    child: const Text("Pick destination"),
                  ),
                if (thisTargetUri != null) ...[
                  Row(
                    children: [
                      Flexible(child: Text(Uri.decodeFull(thisTargetUri))),
                      if (thisConvertProgress == null && !done)
                        IconButton(
                          onPressed: () => setState(() {
                            targetUri = null;
                            done = false;
                          }),
                          icon: const Icon(Icons.clear),
                          tooltip: "Clear target destination",
                        ),
                    ],
                  ),
                  Text("Convert:", style: TextTheme.of(context).titleLarge),
                  if (thisConvertProgress == null && !done)
                    ElevatedButton(
                      onPressed: () async {
                        final String? readSafUrl =
                            await FFmpegKitConfig.getSafParameterForRead(
                              thisInputFileInfo.uri,
                            );
                        if (readSafUrl == null) throw Exception("readSafUrl was null!?");

                        final String? writeSafUrl =
                            await FFmpegKitConfig.getSafParameterForWrite(thisTargetUri);
                        if (writeSafUrl == null) {
                          throw Exception("writeSafUrl was null!?");
                        }

                        final double? duration = double.tryParse(
                          thisInputFileInfo.mediaInformation.getDuration() ?? "",
                        );
                        if (duration == null) throw Exception("duration was null!?");

                        setState(() {
                          convertProgress = 0.0;
                          done = false;
                        });
                        await FFmpegKit.executeAsync(
                          "-i $readSafUrl" //input
                          " -c:a libopus" //codec for audio streams: libopus
                          " $writeSafUrl", //output
                          (FFmpegSession session) => setState(() {
                            convertProgress = null;
                            done = true;
                          }),
                          (Log log) {
                            print(log.getMessage());
                          },
                          (Statistics statistics) {
                            setState(() {
                              convertProgress = statistics.getTime() / (duration * 1000);
                            });
                          },
                        );
                      },
                      child: const Text("Convert to Opus"),
                    ),
                ],
                if (thisConvertProgress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: thisConvertProgress,
                      minHeight: 8,
                    ),
                  ),
                if (done)
                  Text(
                    "Done!",
                    style: TextTheme.of(
                      context,
                    ).titleMedium?.copyWith(color: Colors.green),
                  ),
              ],
            ),
    );
  }

  static Future<String?> pickFileRead() async {
    try {
      return await FFmpegKitConfig.selectDocumentForRead();
    } on PlatformException catch (e) {
      if (e.code == "SELECT_CANCELLED") return null;
      rethrow;
    }
  }

  static Future<String?> pickFileWrite(String title, String type) async {
    try {
      return await FFmpegKitConfig.selectDocumentForWrite(title, type);
    } on PlatformException catch (e) {
      if (e.code == "SELECT_CANCELLED") return null;
      rethrow;
    }
  }

  static Future<MediaInformationSession?> getMediaInfo(
    String uri, [
    int? waitTimeout,
  ]) async {
    final String? safUrl = await FFmpegKitConfig.getSafParameterForRead(uri);
    if (safUrl == null) {
      return null;
    }
    final commandArguments = [
      "-hide_banner",
      ...["-v", "error"],
      ...["-print_format", "json"],
      "-show_format",
      "-show_streams",
      "-i",
      safUrl,
    ];
    return FFprobeKit.getMediaInformationFromCommandArguments(
      commandArguments,
      waitTimeout,
    );
  }
}
