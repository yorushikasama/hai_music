import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_quality.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';

class AudioQualitySelector extends StatelessWidget {
  const AudioQualitySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final colors = Provider.of<ThemeProvider>(context).colors;
    final currentQuality = musicProvider.audioQuality;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.high_quality,
                  color: colors.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '音质选择',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 音质列表
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AudioQuality.recommended.length,
            itemBuilder: (context, index) {
              final quality = AudioQuality.recommended[index];
              final isSelected = quality == currentQuality;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accent.withOpacity(0.15)
                        : colors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.music_note,
                    color: isSelected ? colors.accent : colors.textSecondary,
                    size: 24,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      quality.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colors.accent : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (quality.value >= 10)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '高品质',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  quality.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.radio_button_checked,
                        color: colors.accent,
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        color: colors.textSecondary,
                      ),
                onTap: () {
                  musicProvider.setAudioQuality(quality);
                  Navigator.pop(context);
                  
                  // 显示提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已切换到 ${quality.description}'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
