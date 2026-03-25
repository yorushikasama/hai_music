// 平台特定的窗口操作工具

// 条件导入：在非web平台上导入bitsdojo_window，在web平台上导入本地实现
import 'window_utils_impl.dart' if (dart.library.html) 'window_utils_web.dart';

export 'window_utils_impl.dart' if (dart.library.html) 'window_utils_web.dart';
