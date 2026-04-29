import 'package:flutter/material.dart';

import '../../theme/app_styles.dart';

/// 存储配置表单字段构建器
///
/// 封装 Supabase 和 R2 配置表单的通用字段构建逻辑
class StorageConfigFormBuilder {
  static Widget buildSectionTitle(String title, ThemeColors colors) {
    return Text(
      title,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static Widget buildTextField({
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
            color: colors.textSecondary.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          labelStyle: TextStyle(color: colors.textSecondary),
          hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(AppStyles.spacingM),
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      ),
    );
  }

  static Widget buildInfoCard(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppStyles.spacingM),
      decoration: AppStyles.glassDecoration(
        color: colors.accent,
        opacity: 0.1,
        borderColor: colors.accent.withValues(alpha: 0.3),
        isLight: colors.isLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.accent, size: 20),
              const SizedBox(width: AppStyles.spacingS),
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
          const SizedBox(height: AppStyles.spacingM),
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
