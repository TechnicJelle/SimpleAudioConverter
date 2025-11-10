import "package:ffmpeg_kit_flutter_new_audio/media_information.dart";
import "package:flutter/material.dart";

import "stream_information_view.dart";
import "utils.dart";

class MediaInformationView extends StatelessWidget {
  final MediaInformation info;

  const MediaInformationView({required this.info, super.key});

  @override
  Widget build(BuildContext context) {
    final int? bitrateNum = int.tryParse(info.getBitrate() ?? "");
    final String? bitrate = bitrateNum == null
        ? null
        : "${(bitrateNum / 1000.0).toStringAsFixed(0)} Kbps";

    final double? durationNum = double.tryParse(info.getDuration() ?? "");
    final String? duration = durationNum == null ? null : formatSeconds(durationNum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Media Information:", style: TextTheme.of(context).titleLarge),
        Table(
          children: [
            TableRow(children: [const Text("Format:"), nText(info.getFormat())]),
            TableRow(children: [const Text("Size:"), nText(strToSize(info.getSize()))]),
            TableRow(children: [const Text("Duration:"), nText(duration)]),
            TableRow(children: [const Text("Bitrate:"), nText(bitrate)]),
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
