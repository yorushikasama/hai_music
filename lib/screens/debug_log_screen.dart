import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// 调试日志查看器
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          '调试日志',
          style: TextStyle(color: colors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.textSecondary),
            onPressed: () {
              setState(() {
                DebugLogger.clear();
              });
            },
            tooltip: '清空日志',
          ),
        ],
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: DebugLogger.logs,
        builder: (context, logs, _) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 80,
                    color: colors.textSecondary.withOpacity(0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '暂无日志',
                    style: TextStyle(
                      fontSize: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '尝试播放音乐来生成日志',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final isError = log.contains('❌') || log.contains('ERROR');
              final isSuccess = log.contains('✅') || log.contains('SUCCESS');
              final isWarning = log.contains('⚠️') || log.contains('WARNING');

              Color textColor = colors.textPrimary;
              Color bgColor = colors.surface;

              if (isError) {
                textColor = Colors.red;
                bgColor = Colors.red.withOpacity(0.1);
              } else if (isSuccess) {
                textColor = Colors.green;
                bgColor = Colors.green.withOpacity(0.1);
              } else if (isWarning) {
                textColor = Colors.orange;
                bgColor = Colors.orange.withOpacity(0.1);
              }

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: textColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: SelectableText(
                  log,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: textColor,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {});
        },
        backgroundColor: colors.accent,
        child: Icon(Icons.refresh),
        tooltip: '刷新',
      ),
    );
  }
}

/// 调试日志管理器
class DebugLogger {
  static final ValueNotifier<List<String>> logs = ValueNotifier<List<String>>([]);
  static const int maxLogs = 500; // 最多保存500条日志

  /// 添加日志
  static void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    
    final currentLogs = List<String>.from(logs.value);
    currentLogs.add(logMessage);
    
    // 保持日志数量在限制内
    if (currentLogs.length > maxLogs) {
      currentLogs.removeAt(0);
    }
    
    logs.value = currentLogs;
    
    // 同时输出到控制台
    print(logMessage);
  }

  /// 清空日志
  static void clear() {
    logs.value = [];
  }
}
