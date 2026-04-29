/// UI辅助服务模块
///
/// 提供与UI交互相关的辅助服务，不涉及核心业务逻辑。
///
/// 关键服务：
/// - [SleepTimerService] — 睡眠定时器，倒计时暂停播放
/// - [KeyboardShortcutService] — 键盘快捷键，桌面端全局快捷键支持
/// - [PlayHistoryService] — 播放历史，SP存储(上限100条)
/// - [DataPurgeService] — 数据清除，9类数据全量清除
library ui;

export 'sleep_timer_service.dart';
export 'keyboard_shortcut_service.dart';
export 'play_history_service.dart';
export 'data_purge_service.dart';
