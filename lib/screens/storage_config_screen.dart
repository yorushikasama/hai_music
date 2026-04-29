import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/storage_config.dart';
import '../providers/favorite_provider.dart';
import '../providers/theme_provider.dart';
import '../services/favorite/clipboard_config_parser.dart';
import '../theme/app_styles.dart';
import '../utils/snackbar_util.dart';
import '../widgets/draggable_window_area.dart';
import 'storage/storage_config_dialogs.dart';
import 'storage/storage_config_form_builder.dart';

/// 存储配置界面
class StorageConfigScreen extends StatefulWidget {
  const StorageConfigScreen({super.key});

  @override
  State<StorageConfigScreen> createState() => _StorageConfigScreenState();
}

class _StorageConfigScreenState extends State<StorageConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _supabaseUrlController;
  late TextEditingController _supabaseKeyController;
  late TextEditingController _r2EndpointController;
  late TextEditingController _r2AccessKeyController;
  late TextEditingController _r2SecretKeyController;
  late TextEditingController _r2BucketController;
  late TextEditingController _r2RegionController;
  late TextEditingController _r2CustomDomainController;

  bool _enableSync = false;
  bool _isLoading = false;
  bool _obscureSupabaseKey = true;
  bool _obscureR2AccessKey = true;
  bool _obscureR2SecretKey = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    unawaited(_loadConfig());
  }

  void _initControllers() {
    _supabaseUrlController = TextEditingController();
    _supabaseKeyController = TextEditingController();
    _r2EndpointController = TextEditingController();
    _r2AccessKeyController = TextEditingController();
    _r2SecretKeyController = TextEditingController();
    _r2BucketController = TextEditingController();
    _r2RegionController = TextEditingController(text: 'auto');
    _r2CustomDomainController = TextEditingController();
  }

  Future<void> _loadConfig() async {
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    final config = await favoriteProvider.favoriteManager.getConfigAsync();

    setState(() {
      _supabaseUrlController.text = config.supabaseUrl;
      _supabaseKeyController.text = config.supabaseAnonKey;
      _r2EndpointController.text = config.r2Endpoint;
      _r2AccessKeyController.text = config.r2AccessKey;
      _r2SecretKeyController.text = config.r2SecretKey;
      _r2BucketController.text = config.r2BucketName;
      _r2RegionController.text = config.r2Region;
      _r2CustomDomainController.text = config.r2CustomDomain ?? '';
      _enableSync = config.enableSync;
    });
  }

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    _r2EndpointController.dispose();
    _r2AccessKeyController.dispose();
    _r2SecretKeyController.dispose();
    _r2BucketController.dispose();
    _r2RegionController.dispose();
    _r2CustomDomainController.dispose();
    super.dispose();
  }

  Future<void> _importFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
        if (mounted) {
          AppSnackBar.showWithContext(context, '粘贴板为空', type: SnackBarType.warning);
        }
        return;
      }

      final clipboardText = clipboardData.text!;

      if (!ClipboardConfigParser.validateConfigText(clipboardText)) {
        if (mounted) StorageConfigDialogs.showImportHelpDialog(context);
        return;
      }

      final config = ClipboardConfigParser.parseConfig(clipboardText);
      if (config == null) {
        if (mounted) {
          AppSnackBar.showWithContext(context, '无法解析配置，请检查格式', type: SnackBarType.error);
        }
        return;
      }

      final confirmed = await StorageConfigDialogs.showImportConfirmDialog(context, config);
      if (confirmed != true) return;

      setState(() {
        _supabaseUrlController.text = config.supabaseUrl;
        _supabaseKeyController.text = config.supabaseAnonKey;
        _r2EndpointController.text = config.r2Endpoint;
        _r2AccessKeyController.text = config.r2AccessKey;
        _r2SecretKeyController.text = config.r2SecretKey;
        _r2BucketController.text = config.r2BucketName;
        _r2RegionController.text = config.r2Region;
        _r2CustomDomainController.text = config.r2CustomDomain ?? '';
      });

      if (mounted) {
        AppSnackBar.showWithContext(context, '配置导入成功，请检查后保存', type: SnackBarType.success);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showWithContext(context, '导入失败：$e', type: SnackBarType.error);
      }
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final config = StorageConfig(
        supabaseUrl: _supabaseUrlController.text.trim(),
        supabaseAnonKey: _supabaseKeyController.text.trim(),
        r2Endpoint: _r2EndpointController.text.trim(),
        r2AccessKey: _r2AccessKeyController.text.trim(),
        r2SecretKey: _r2SecretKeyController.text.trim(),
        r2BucketName: _r2BucketController.text.trim(),
        r2Region: _r2RegionController.text.trim(),
        r2CustomDomain: _r2CustomDomainController.text.trim().isEmpty
            ? null
            : _r2CustomDomainController.text.trim(),
        enableSync: _enableSync,
      );

      final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
      final success = await favoriteProvider.favoriteManager.updateConfig(config);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        if (_enableSync) {
          await favoriteProvider.refreshFavoriteSongs();
        }
        if (!mounted) return;
        AppSnackBar.showWithContext(context, '配置保存成功', type: SnackBarType.success);

        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      } else {
        AppSnackBar.showWithContext(
          context,
          '配置保存失败，请重试',
          type: SnackBarType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      AppSnackBar.showWithContext(context, '保存配置时发生错误：$e', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: DraggableWindowArea(
          child: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '云端同步配置',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(Icons.content_paste, color: colors.accent),
                  onPressed: _importFromClipboard,
                  tooltip: '从粘贴板导入',
                ),
                TextButton(
                  onPressed: _saveConfig,
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppStyles.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSyncSwitch(colors),
              const SizedBox(height: AppStyles.spacingL),
              StorageConfigFormBuilder.buildSectionTitle('Supabase 数据库配置', colors),
              const SizedBox(height: AppStyles.spacingM),
              _buildSupabaseFields(colors),
              const SizedBox(height: AppStyles.spacingXL),
              StorageConfigFormBuilder.buildSectionTitle('Cloudflare R2 存储配置', colors),
              const SizedBox(height: AppStyles.spacingM),
              _buildR2Fields(colors),
              const SizedBox(height: AppStyles.spacingXL),
              StorageConfigFormBuilder.buildInfoCard(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncSwitch(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.spacingM),
      decoration: AppStyles.glassDecoration(
        color: colors.surface,
        opacity: 0.8,
        borderColor: colors.border,
        isLight: colors.isLight,
      ),
      child: SwitchListTile(
        title: Text(
          '启用云端同步',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '收藏的歌曲将自动同步到云端',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        value: _enableSync,
        activeTrackColor: colors.accent,
        onChanged: (value) => setState(() => _enableSync = value),
      ),
    );
  }

  Widget _buildSupabaseFields(ThemeColors colors) {
    return Column(
      children: [
        StorageConfigFormBuilder.buildTextField(
          controller: _supabaseUrlController,
          label: 'Supabase URL',
          hint: 'https://xxx.supabase.co',
          colors: colors,
          validator: (value) {
            if (_enableSync && (value == null || value.isEmpty)) return '请输入 Supabase URL';
            return null;
          },
        ),
        const SizedBox(height: AppStyles.spacingM),
        StorageConfigFormBuilder.buildTextField(
          controller: _supabaseKeyController,
          label: 'Supabase Anon Key',
          hint: '输入您的 Anon Key',
          colors: colors,
          obscureText: _obscureSupabaseKey,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSupabaseKey ? Icons.visibility_off : Icons.visibility,
              color: colors.textSecondary,
            ),
            onPressed: () => setState(() => _obscureSupabaseKey = !_obscureSupabaseKey),
          ),
          validator: (value) {
            if (_enableSync && (value == null || value.isEmpty)) return '请输入 Supabase Anon Key';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildR2Fields(ThemeColors colors) {
    return Column(
      children: [
        StorageConfigFormBuilder.buildTextField(
          controller: _r2EndpointController,
          label: 'R2 Endpoint',
          hint: 'https://xxx.r2.cloudflarestorage.com',
          colors: colors,
          validator: (value) {
            if (_enableSync && (value == null || value.isEmpty)) return '请输入 R2 Endpoint';
            return null;
          },
        ),
        const SizedBox(height: AppStyles.spacingM),
        StorageConfigFormBuilder.buildTextField(
          controller: _r2AccessKeyController,
          label: 'Access Key ID',
          hint: '输入 Access Key',
          colors: colors,
          obscureText: _obscureR2AccessKey,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureR2AccessKey ? Icons.visibility_off : Icons.visibility,
              color: colors.textSecondary,
            ),
            onPressed: () => setState(() => _obscureR2AccessKey = !_obscureR2AccessKey),
          ),
          validator: (value) {
            if (_enableSync && (value == null || value.isEmpty)) return '请输入 Access Key';
            return null;
          },
        ),
        const SizedBox(height: AppStyles.spacingM),
        StorageConfigFormBuilder.buildTextField(
          controller: _r2SecretKeyController,
          label: 'Secret Access Key',
          hint: '输入 Secret Key',
          colors: colors,
          obscureText: _obscureR2SecretKey,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureR2SecretKey ? Icons.visibility_off : Icons.visibility,
              color: colors.textSecondary,
            ),
            onPressed: () => setState(() => _obscureR2SecretKey = !_obscureR2SecretKey),
          ),
          validator: (value) {
            if (_enableSync && (value == null || value.isEmpty)) return '请输入 Secret Key';
            return null;
          },
        ),
        const SizedBox(height: AppStyles.spacingM),
        StorageConfigFormBuilder.buildTextField(
          controller: _r2BucketController,
          label: 'Bucket 名称',
          hint: 'my-music-bucket',
          colors: colors,
          validator: (value) {
            if (_enableSync && (value == null || value.isEmpty)) return '请输入 Bucket 名称';
            return null;
          },
        ),
        const SizedBox(height: AppStyles.spacingM),
        StorageConfigFormBuilder.buildTextField(
          controller: _r2RegionController,
          label: 'Region',
          hint: 'auto',
          colors: colors,
        ),
        const SizedBox(height: AppStyles.spacingM),
        StorageConfigFormBuilder.buildTextField(
          controller: _r2CustomDomainController,
          label: 'R2 自定义域名（可选）',
          hint: 'music.ysnight.cn',
          colors: colors,
          helperText: '在 Cloudflare R2 控制台绑定自定义域名后填写\n使用自定义域名可获得永久有效的 URL',
        ),
      ],
    );
  }
}
