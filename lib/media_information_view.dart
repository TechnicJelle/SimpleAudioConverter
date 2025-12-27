import "package:ffmpeg_kit_flutter_new_audio/media_information.dart";
import "package:flutter/material.dart";

import "picked_file_info.dart";
import "stream_information_view.dart";
import "utils.dart";

class MediaInformationView extends StatefulWidget {
  final PickedFileInfo info;

  const MediaInformationView({required this.info, super.key});

  @override
  State<MediaInformationView> createState() => _MediaInformationViewState();
}

class _MediaInformationViewState extends State<MediaInformationView> {
  MediaInformation get info => widget.info.mediaInformation;

  String get filename => widget.info.filename;

  bool open = false;

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return InkWell(
        onTap: () => setState(() => open = true),
        child: Row(
          children: [
            const Icon(Icons.keyboard_arrow_right),
            Text("Media Information", style: TextTheme.of(context).titleLarge),
          ],
        ),
      );
    }

    final int? bitrateNum = int.tryParse(info.getBitrate() ?? "");
    final String? bitrate = bitrateNum == null
        ? null
        : "${(bitrateNum / 1000.0).toStringAsFixed(0)} Kbps";

    final double? durationNum = double.tryParse(info.getDuration() ?? "");
    final String? duration = durationNum == null ? null : formatSeconds(durationNum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => open = false),
          child: Row(
            children: [
              const Icon(Icons.keyboard_arrow_down),
              Text("Media Information", style: TextTheme.of(context).titleLarge),
            ],
          ),
        ),
        //filenames can get long, so it's outside of the table, to ensure it doesn't get wrapped _too_ much
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tr("File name:  ", filename, context, inRow: true),
        ),
        const SizedBox(height: 1),
        Table(
          children: [
            TableRow(children: tr("Format:", info.getFormat(), context)),
            TableRow(children: tr("Size:", strToSize(info.getSize()), context)),
            TableRow(children: tr("Duration:", duration, context)),
            TableRow(children: tr("Bitrate:", bitrate, context)),
          ],
        ),
        const SizedBox(height: 8),
        for (final stream in info.getStreams()) StreamInformationView(info: stream),
      ],
    );
  }

  String formatSeconds(double totalSeconds) {
    final double hours = totalSeconds / 3600;
    final double minutes = (totalSeconds % 3600) / 60;
    final double seconds = totalSeconds % 60;
    final double milliseconds = (totalSeconds * 1000) % 1000;

    final int iHours = hours.floor();
    final int iMinutes = minutes.floor();
    final int iSeconds = seconds.floor();
    final int iMilliseconds = milliseconds.floor();

    return "$iHours:${iMinutes.toString().padLeft(2, "0")}:${iSeconds.toString().padLeft(2, "0")}.${iMilliseconds.toString().padLeft(3, "0")}";
  }
}
