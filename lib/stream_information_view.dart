import "package:ffmpeg_kit_flutter_new_audio/stream_information.dart";
import "package:flutter/material.dart";

import "utils.dart";

class StreamInformationView extends StatelessWidget {
  final StreamInformation info;

  const StreamInformationView({required this.info, super.key});

  @override
  Widget build(BuildContext context) {
    final int? bitrateNum = int.tryParse(info.getBitrate() ?? "");
    final String? bitrate = bitrateNum == null
        ? null
        : "${(bitrateNum / 1000.0).toStringAsFixed(0)} Kbps";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Stream ${info.getIndex()} Information:",
          style: TextTheme.of(context).titleMedium,
        ),
        Table(
          children: [
            TableRow(
              children: [const Text("Type:"), nText(info.getType())],
            ),
            TableRow(children: [const Text("Codec:"), nText(info.getCodec())]),
            TableRow(children: [const Text("Format:"), nText(info.getFormat())]),
            TableRow(
              children: [const Text("Channel Layout:"), nText(info.getChannelLayout())],
            ),
            TableRow(children: [const Text("Bitrate:"), nText(bitrate)]),
            TableRow(
              children: [const Text("Sample Rate:"), nText(info.getSampleRate())],
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
