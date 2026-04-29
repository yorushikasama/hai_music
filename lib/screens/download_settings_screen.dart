import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audio_quality.dart';
import '../providers/theme_provider.dart';
import '../services/download/download_service.dart';
import '../services/ui/data_purge_service.dart';
import '../theme/app_styles.dart';
import '../utils/format_utils.dart';
import '../utils/snackbar_util.dart';
import '../widgets/confirm_delete_dialog.dart';

/// 下载设置页面
/// 提供WiFi限制、并发下载数、存储空间可视化、数据管理等设置项
class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  bool _wifiOnly = false;
  int _maxConcurrent = 3;
  bool _loading = true;

  int _totalSize = 0;
  int _songCount = 0;
  Map<String, int> _sizeByQuality = {};

  String _cacheSizeLabel = '';
  bool _cacheLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
    unawaited(_loadCacheInfo());
  }

  Future<void> _loadSettings() async {
    final downloadService = DownloadService();
    await downloadService.init();
    final wifiOnly = await downloadService.getWifiOnlyDownload();
    final maxConcurrent = await downloadService.getMaxConcurrentDownloads();

    final totalSize = await downloadService.getDownloadedSize();
    final songCount = await downloadService.getDownloadedCount();
    final sizeByQuality = await downloadService.getSizeByQuality();

    if (!mounted) return;
    setState(() {
      _wifiOnly = wifiOnly;
      _maxConcurrent = maxConcurrent;
      _totalSize = totalSize;
      _songCount = songCount;
      _sizeByQuality = sizeByQuality;
      _loading = false;
    });
  }

  Future<void> _loadCacheInfo() async {
    try {
      final cacheInfo = await DataPurgeService().getCacheInfo();
      if (!mounted) return;
      setState(() {
        _cacheSizeLabel = FormatUtils.formatSize(cacheInfo.totalSize);
        _cacheLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cacheSizeLabel = '未知';
        _cacheLoading = false;
      });
    }
  }

  Future<void> _setWifiOnly(bool value) async {
    await DownloadService().setWifiOnlyDownload(value);
    setState(() {
      _wifiOnly = value;
    });
  }

  Future<void> _setMaxConcurrent(int value) async {
    await DownloadService().setMaxConcurrentDownloads(value);
    setState(() {
      _maxConcurrent = value;
    });
  }

  Future<void> _handleClearCache() async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    ));

    final cacheInfo = await DataPurgeService().getCacheInfo(forceRefresh: true);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;

    final totalSizeStr = FormatUtils.formatSize(cacheInfo.totalSize);
    final audioSizeStr = FormatUtils.formatSize(cacheInfo.audioSize);
    final coverSizeStr = FormatUtils.formatSize(cacheInfo.coverSize);

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.cache,
      title: '清理缓存',
      message: '当前缓存大小：$totalSizeStr\n'
          '音频缓存：$audioSizeStr | 封面缓存：$coverSizeStr\n'
          '图片缓存：${FormatUtils.formatSize(cacheInfo.imageSize)}\n\n'
          '清理缓存将删除音频、封面和图片缓存\n（不包括下载的歌曲）',
      confirmText: '清理',
      icon: Icons.cleaning_services_rounded,
      destructive: false,
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final navigator = Navigator.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    ));

    final success = await DataPurgeService().clearAllCache();

    if (!mounted) {
      navigator.pop();
      return;
    }

    Navigator.of(context).pop();

    if (!mounted) return;

    AppSnackBar.show(
      success ? '缓存清理完成' : '缓存清理失败，请重试',
      type: success ? SnackBarType.success : SnackBarType.error,
    );

    unawaited(_loadCacheInfo());
    unawaited(_loadSettings());
  }

  Future<void> _handlePurgeAllData() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.allData,
      title: '彻底清除所有数据',
      message: '将删除以下所有数据：\n'
          '• 播放缓存、图片缓存、歌词缓存\n'
          '• 持久化封面、数据缓存\n'
          '• 已下载的歌曲文件\n'
          '• 数据库记录、偏好设置\n'
          '• 安全存储中的凭据\n\n'
          '此操作不可恢复！',
      confirmText: '彻底清除',
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed != true) return;

    final secondConfirmed = await ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.allData,
      title: '最后确认',
      message: '真的要删除所有数据吗？\n应用将恢复到初始状态。',
      confirmText: '确认清除',
      icon: Icons.warning_amber_rounded,
    );

    if (secondConfirmed != true) return;

    if (!mounted) return;

    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final textTheme = Theme.of(context).textTheme;
    final navigator = Navigator.of(context);

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppStyles.spacingXXXL),
          padding: const EdgeInsets.all(AppStyles.spacingXXL),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppStyles.borderRadiusLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.accent),
              const SizedBox(height: AppStyles.spacingXXL),
              Text(
                '正在清除数据...',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppStyles.spacingS),
              Text(
                '请稍候',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ));

    final result = await DataPurgeService().purgeAll();

    if (!mounted) {
      navigator.pop();
      return;
    }

    navigator.pop();

    if (!mounted) return;

    AppSnackBar.showWithContext(
      context,
      result.allSuccess
          ? '所有数据已彻底清除'
          : '部分数据清除失败: ${result.summary}',
      type: result.allSuccess ? SnackBarType.success : SnackBarType.warning,
      duration: const Duration(seconds: 4),
    );

    unawaited(_loadCacheInfo());
    unawaited(_loadSettings());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '下载设置',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppStyles.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNetworkSection(colors),
                  const SizedBox(height: AppStyles.spacingXL),
                  _buildDownloadSection(colors),
                  const SizedBox(height: AppStyles.spacingXL),
                  _buildStorageSection(colors),
                  const SizedBox(height: AppStyles.spacingXL),
                  _buildDataManagementSection(colors),
                  const SizedBox(height: AppStyles.spacingXXXL),
                ],
              ),
            ),
    );
  }

  Widget _buildNetworkSection(ThemeColors colors) {
    return _buildSection(
      colors: colors,
      title: '网络设置',
      icon: Icons.wifi,
      children: [
        SwitchListTile(
          title: Text('仅WiFi下载', style: TextStyle(color: colors.textPrimary)),
          subtitle: Text(
            '开启后，仅在WiFi网络下才会下载歌曲',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          value: _wifiOnly,
          onChanged: _setWifiOnly,
          activeThumbColor: colors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildDownloadSection(ThemeColors colors) {
    return _buildSection(
      colors: colors,
      title: '下载设置',
      icon: Icons.download,
      children: [
        ListTile(
          title: Text('同时下载数', style: TextStyle(color: colors.textPrimary)),
          subtitle: Text(
            '同时下载的歌曲数量，数量越多下载越快',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          trailing: _buildConcurrentSelector(colors),
        ),
      ],
    );
  }

  Widget _buildConcurrentSelector(ThemeColors colors) {
    return DropdownButton<int>(
      value: _maxConcurrent,
      underline: const SizedBox(),
      icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
      items: [1, 2, 3, 4, 5].map((value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(
            '$value',
            style: TextStyle(color: colors.textPrimary),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) _setMaxConcurrent(value);
      },
    );
  }

  Widget _buildStorageSection(ThemeColors colors) {
    final totalSizeStr = FormatUtils.formatSize(_totalSize);

    return _buildSection(
      colors: colors,
      title: '存储空间',
      icon: Icons.storage,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('已下载歌曲', style: TextStyle(color: colors.textPrimary)),
              Text(
                '$_songCount 首',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('总占用空间', style: TextStyle(color: colors.textPrimary)),
              Text(
                totalSizeStr,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_sizeByQuality.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: colors.border.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 8),
          ..._buildQualityBreakdown(colors),
        ],
      ],
    );
  }

  List<Widget> _buildQualityBreakdown(ThemeColors colors) {
    final widgets = <Widget>[];
    final sortedEntries = _sizeByQuality.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final qualityValue = int.tryParse(entry.key);
      final quality = qualityValue != null
          ? AudioQuality.fromValue(qualityValue)
          : null;
      final label = quality?.label ?? '未知';
      final sizeStr = FormatUtils.formatSize(entry.value);
      final percentage = _totalSize > 0 ? (entry.value / _totalSize * 100) : 0.0;

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (quality != null)
                        Icon(quality.icon, size: 16, color: quality.color)
                      else
                        Icon(Icons.music_note, size: 16, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Text(label, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                    ],
                  ),
                  Text(
                    '$sizeStr (${percentage.toStringAsFixed(0)}%)',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: colors.border.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    quality?.color ?? colors.textSecondary,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildDataManagementSection(ThemeColors colors) {
    return _buildSection(
      colors: colors,
      title: '数据管理',
      icon: Icons.manage_history_rounded,
      children: [
        ListTile(
          leading: Icon(
            Icons.cleaning_services_outlined,
            color: colors.warning,
            size: 22,
          ),
          title: Text('清理缓存', style: TextStyle(color: colors.textPrimary)),
          subtitle: Text(
            '清理播放缓存、封面缓存和图片缓存\n不影响已下载的歌曲',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          trailing: _cacheLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppStyles.spacingM,
                    vertical: AppStyles.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.1),
                    borderRadius: AppStyles.borderRadiusSmall,
                  ),
                  child: Text(
                    _cacheSizeLabel,
                    style: TextStyle(
                      color: colors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          onTap: _handleClearCache,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: colors.border.withValues(alpha: 0.3)),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: colors.error,
            size: 22,
          ),
          title: Text(
            '彻底清除数据',
            style: TextStyle(color: colors.error),
          ),
          subtitle: Text(
            '删除所有应用数据，包括下载、缓存、设置\n此操作不可恢复',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: colors.error.withValues(alpha: 0.5),
            size: 20,
          ),
          onTap: _handlePurgeAllData,
        ),
      ],
    );
  }

  Widget _buildSection({
    required ThemeColors colors,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
