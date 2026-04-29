import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../extensions/duration_extension.dart';
import '../../../providers/music_provider.dart';

class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({super.key});

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();

    return StreamBuilder<Duration>(
      stream: musicProvider.positionStream,
      initialData: musicProvider.currentPosition,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: musicProvider.durationStream,
          initialData: musicProvider.totalDuration,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            final sliderValue = min(
              _dragValue ?? position.inMilliseconds.toDouble(),
              duration.inMilliseconds.toDouble(),
            );

            final displayPosition = _dragValue != null
                ? Duration(milliseconds: _dragValue?.round() ?? 0)
                : position;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    max: duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: duration.inMilliseconds > 0
                        ? sliderValue.clamp(0.0, duration.inMilliseconds.toDouble())
                        : 0.0,
                    onChanged: (value) {
                      setState(() {
                        _dragValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      musicProvider.seekTo(Duration(milliseconds: value.round()));
                      setState(() {
                        _dragValue = null;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayPosition.toMinutesSeconds(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        duration.toMinutesSeconds(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
