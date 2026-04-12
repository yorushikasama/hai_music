import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_quality.dart';
import '../providers/audio_settings_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';

class AudioQualitySelector extends StatelessWidget {
  const AudioQualitySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);
    final audioSettings = Provider.of<AudioSettingsProvider>(context);
    final currentQuality = audioSettings.audioQuality;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(colors),
          _buildHeader(context, colors, currentQuality),
          Divider(height: 1, color: colors.border),
          Flexible(
            child: isWideScreen
                ? _buildWideLayout(context, colors, currentQuality, musicProvider)
                : _buildNarrowLayout(context, colors, currentQuality, musicProvider),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildDragHandle(ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colors.textSecondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeColors colors, AudioQuality currentQuality) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: currentQuality.gradientColors,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: currentQuality.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              currentQuality.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '音质选择',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: currentQuality.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentQuality.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: currentQuality.color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${currentQuality.description} · ${currentQuality.bitrate}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textSecondary, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    ThemeColors colors,
    AudioQuality currentQuality,
    MusicProvider musicProvider,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: AudioQualityCategory.values.length,
      itemBuilder: (context, index) {
        final category = AudioQualityCategory.values[index];
        final qualities = AudioQuality.values
            .where((q) => q.category == category)
            .toList();
        return _buildCategorySection(
          context,
          colors,
          qualities,
          currentQuality,
          musicProvider,
        );
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ThemeColors colors,
    AudioQuality currentQuality,
    MusicProvider musicProvider,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: AudioQualityCategory.values.length,
      itemBuilder: (context, index) {
        final category = AudioQualityCategory.values[index];
        final qualities = AudioQuality.values
            .where((q) => q.category == category)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryHeader(colors, category),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: qualities.map((quality) {
                final isSelected = quality == currentQuality;
                return _QualityChip(
                  quality: quality,
                  isSelected: isSelected,
                  colors: colors,
                  onTap: () => _selectQuality(context, musicProvider, quality),
                );
              }).toList(),
            ),
            if (index < AudioQualityCategory.values.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: colors.border),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    ThemeColors colors,
    List<AudioQuality> qualities,
    AudioQuality currentQuality,
    MusicProvider musicProvider,
  ) {
    if (qualities.isEmpty) return const SizedBox.shrink();

    final category = qualities.first.category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryHeader(colors, category),
        ...qualities.map((quality) => _QualityTile(
              quality: quality,
              isSelected: quality == currentQuality,
              colors: colors,
              onTap: () => _selectQuality(context, musicProvider, quality),
            )),
      ],
    );
  }

  Widget _buildCategoryHeader(ThemeColors colors, AudioQualityCategory category) {
    final iconData = switch (category) {
      AudioQualityCategory.standard => Icons.audiotrack_rounded,
      AudioQualityCategory.highQuality => Icons.graphic_eq_rounded,
      AudioQualityCategory.lossless => Icons.workspace_premium_outlined,
    };
    final title = switch (category) {
      AudioQualityCategory.standard => '标准音质',
      AudioQualityCategory.highQuality => '高品质',
      AudioQualityCategory.lossless => '无损音质',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Icon(iconData, size: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: colors.border)),
        ],
      ),
    );
  }

  Future<void> _selectQuality(
    BuildContext context,
    MusicProvider musicProvider,
    AudioQuality quality,
  ) async {
    Navigator.pop(context);

    final messenger = ScaffoldMessenger.of(context);

    await Provider.of<AudioSettingsProvider>(context, listen: false).setAudioQuality(quality);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(quality.icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('已切换到 ${quality.description}'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: quality.color.withValues(alpha: 0.85),
      ),
    );
  }
}

class _QualityTile extends StatefulWidget {
  final AudioQuality quality;
  final bool isSelected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _QualityTile({
    required this.quality,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_QualityTile> createState() => _QualityTileState();
}

class _QualityTileState extends State<_QualityTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.isSelected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _QualityTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      _controller.animateTo(widget.isSelected ? 1.0 : 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final quality = widget.quality;
    final isSelected = widget.isSelected;

    return Semantics(
      label: quality.semanticLabel,
      selected: isSelected,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? quality.color.withValues(alpha: 0.1)
                  : _isHovered
                      ? colors.card.withValues(alpha: 0.8)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(
                      color: quality.color.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                  : _isHovered
                      ? Border.all(color: colors.border.withValues(alpha: 0.5))
                      : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: quality.gradientColors,
                          )
                        : null,
                    color: isSelected ? null : colors.card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: quality.color.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : quality.icon,
                    color: isSelected ? Colors.white : colors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(colors: quality.gradientColors)
                                  : null,
                              color: isSelected ? null : quality.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              quality.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : quality.color,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              quality.description,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? colors.textPrimary : colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quality.bitrate,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: quality.gradientColors,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityChip extends StatefulWidget {
  final AudioQuality quality;
  final bool isSelected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _QualityChip({
    required this.quality,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_QualityChip> createState() => _QualityChipState();
}

class _QualityChipState extends State<_QualityChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final quality = widget.quality;
    final isSelected = widget.isSelected;
    final colors = widget.colors;

    return Semantics(
      label: quality.semanticLabel,
      selected: isSelected,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: quality.gradientColors,
                    )
                  : null,
              color: isSelected ? null : (_isHovered ? colors.card : colors.card.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : Border.all(
                      color: _isHovered
                          ? quality.color.withValues(alpha: 0.5)
                          : colors.border,
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: quality.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  quality.icon,
                  size: 24,
                  color: isSelected ? Colors.white : quality.color,
                ),
                const SizedBox(height: 8),
                Text(
                  quality.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : colors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quality.bitrate,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
