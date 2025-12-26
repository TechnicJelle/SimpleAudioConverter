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
          style: TextTheme.of(
            context,
          ).titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        Table(
          children: [
            TableRow(children: tr("Type:", info.getType(), context)),
            TableRow(children: tr("Codec:", info.getCodec(), context)),
            TableRow(children: tr("Format:", info.getFormat(), context)),
            TableRow(children: tr("Channel Layout:", info.getChannelLayout(), context)),
            TableRow(children: tr("Bitrate:", bitrate, context)),
            TableRow(children: tr("Sample Rate:", info.getSampleRate(), context)),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
