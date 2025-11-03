import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/storage_config.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../services/clipboard_config_parser.dart';

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
    _loadConfig();
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

  void _loadConfig() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final config = musicProvider.favoriteManager.getConfig();
    
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
      // 读取粘贴板内容
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('粘贴板为空'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final clipboardText = clipboardData.text!;
      
      // 验证配置格式
      if (!ClipboardConfigParser.validateConfigText(clipboardText)) {
        if (mounted) {
          _showImportHelpDialog();
        }
        return;
      }

      // 解析配置
      final config = ClipboardConfigParser.parseConfig(clipboardText);
      if (config == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法解析配置，请检查格式'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 填充到输入框
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 配置导入成功！请检查后保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImportHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置格式说明'),
        content: SingleChildScrollView(
          child: Text(
            ClipboardConfigParser.generateExample(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final success = await musicProvider.favoriteManager.updateConfig(config);

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '配置保存成功' : '配置保存失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        Navigator.pop(context);
      }
    }
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(AppStyles.spacingL),
          children: [
            // 启用同步开关
            Container(
              padding: EdgeInsets.all(AppStyles.spacingM),
              decoration: AppStyles.glassDecoration(
                color: colors.surface,
                opacity: 0.8,
                borderColor: colors.border,
                isLight: colors.isLight,
              ),
              child: SwitchListTile(
                title: Text(
                  '启用云端同步',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '收藏的歌曲将自动同步到云端',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                value: _enableSync,
                activeColor: colors.accent,
                onChanged: (value) {
                  setState(() => _enableSync = value);
                },
              ),
            ),
            SizedBox(height: AppStyles.spacingL),

            // Supabase 配置
            _buildSectionTitle('Supabase 数据库配置', colors),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
              controller: _supabaseUrlController,
              label: 'Supabase URL',
              hint: 'https://xxx.supabase.co',
              colors: colors,
              validator: (value) {
                if (_enableSync && (value == null || value.isEmpty)) {
                  return '请输入 Supabase URL';
                }
                return null;
              },
            ),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
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
                onPressed: () {
                  setState(() => _obscureSupabaseKey = !_obscureSupabaseKey);
                },
              ),
              validator: (value) {
                if (_enableSync && (value == null || value.isEmpty)) {
                  return '请输入 Supabase Anon Key';
                }
                return null;
              },
            ),
            SizedBox(height: AppStyles.spacingXL),

            // Cloudflare R2 配置
            _buildSectionTitle('Cloudflare R2 存储配置', colors),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
              controller: _r2EndpointController,
              label: 'R2 Endpoint',
              hint: 'https://xxx.r2.cloudflarestorage.com',
              colors: colors,
              validator: (value) {
                if (_enableSync && (value == null || value.isEmpty)) {
                  return '请输入 R2 Endpoint';
                }
                return null;
              },
            ),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
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
                onPressed: () {
                  setState(() => _obscureR2AccessKey = !_obscureR2AccessKey);
                },
              ),
              validator: (value) {
                if (_enableSync && (value == null || value.isEmpty)) {
                  return '请输入 Access Key';
                }
                return null;
              },
            ),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
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
                onPressed: () {
                  setState(() => _obscureR2SecretKey = !_obscureR2SecretKey);
                },
              ),
              validator: (value) {
                if (_enableSync && (value == null || value.isEmpty)) {
                  return '请输入 Secret Key';
                }
                return null;
              },
            ),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
              controller: _r2BucketController,
              label: 'Bucket 名称',
              hint: 'my-music-bucket',
              colors: colors,
              validator: (value) {
                if (_enableSync && (value == null || value.isEmpty)) {
                  return '请输入 Bucket 名称';
                }
                return null;
              },
            ),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
              controller: _r2RegionController,
              label: 'Region',
              hint: 'auto',
              colors: colors,
            ),
            SizedBox(height: AppStyles.spacingM),
            _buildTextField(
              controller: _r2CustomDomainController,
              label: 'R2 自定义域名（可选）',
              hint: 'music.ysnight.cn',
              colors: colors,
              helperText: '在 Cloudflare R2 控制台绑定自定义域名后填写\n使用自定义域名可获得永久有效的 URL',
            ),
            SizedBox(height: AppStyles.spacingXL),

            // 说明文档
            _buildInfoCard(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeColors colors) {
    return Text(
      title,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ThemeColors colors,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Container(
      decoration: AppStyles.glassDecoration(
        color: colors.surface,
        opacity: 0.8,
        borderColor: colors.border,
        isLight: colors.isLight,
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          helperMaxLines: 2,
          helperStyle: TextStyle(
            color: colors.textSecondary.withOpacity(0.7),
            fontSize: 12,
          ),
          labelStyle: TextStyle(color: colors.textSecondary),
          hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.all(AppStyles.spacingM),
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildInfoCard(ThemeColors colors) {
    return Container(
      padding: EdgeInsets.all(AppStyles.spacingM),
      decoration: AppStyles.glassDecoration(
        color: colors.accent,
        opacity: 0.1,
        borderColor: colors.accent.withOpacity(0.3),
        isLight: colors.isLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.accent, size: 20),
              SizedBox(width: AppStyles.spacingS),
              Text(
                '配置说明',
                style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: AppStyles.spacingM),
          Text(
            '1. 在 Supabase 中创建项目并获取 URL 和 Anon Key\n'
            '2. 创建 favorite_songs 表（参考服务代码中的建议结构）\n'
            '3. 在 Cloudflare 中创建 R2 存储桶\n'
            '4. 生成 R2 API 令牌获取 Access Key 和 Secret Key\n'
            '5. 启用同步后，收藏的歌曲将自动下载并上传到云端',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
