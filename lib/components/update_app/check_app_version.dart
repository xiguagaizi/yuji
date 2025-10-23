import 'package:flutter/foundation.dart';
import '../../config/app_config.dart' show AppConfig;
import '../../config/common_config.dart' show commonConfig;
import '../../utils/index.dart' show SpUtil, compareVersion;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/common_service.dart'; // 接口
import '../../utils/tool/perm_util.dart';
import './update_app.dart';

bool _showFlag = false;

/// 检查最新版本APP更新
///
/// [seconds] app多久检查更新，默认12小时
///
/// [forceUpdate] 是否强制更新, 直接显示弹层，默认false
checkAppVersion({int seconds = 60 * 60 * 12, bool forceUpdate = false}) async {
  if (!AppConfig.isUpdateApp || kIsWeb) return;
  if (!(await PermUtil.storagePerm())) return; // 权限申请
  try {
    if (_showFlag) return;
    const String spKey = 'checkAppVerTime'; // 缓存key
    DateTime newTime = DateTime.now(); // 当前时间
    
    // 创建 SpUtil 实例
    final spUtil = await SpUtil.getInstance();
    String oldTimeStr = await spUtil.getData<String>(
      spKey,
      defValue: DateTime.now().add(const Duration(days: -10)).toString(),
    );

    DateTime oldTime = DateTime.parse(oldTimeStr);
    Duration diffTime = newTime.difference(oldTime);
    // 指定时间内不在触发检查更新APP
    if (!forceUpdate) {
      if (diffTime.inSeconds < seconds) {
        _showFlag = false;
        return;
      }
    }

    // TODO:获取最新APP版本, 自定义getNewVersion接口获取
    var resData = await getNewVersion();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // APP版本号对比检查
    if (!compareVersion(resData.version, packageInfo.version) && !forceUpdate) {
      return;
    }
    _showFlag = true;
    // 弹层更新
    showGeneralDialog(
      // ignore: use_build_context_synchronously
      context: commonConfig.getGlobalContext,
      barrierDismissible: !forceUpdate, // 是否点击其他区域消失
      barrierLabel: "",
      barrierColor: Colors.black54, // 遮罩层背景色
      transitionDuration: const Duration(milliseconds: 150), // 弹出的过渡时长
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        // 显示的动画组件
        return ScaleTransition(
          scale: Tween<double>(begin: 0, end: 1).animate(animation),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent, // 背景颜色
          child: UpdateAppVersion(
            // TODO: 传入新版本APP相关参数、版本号、更新内容、下载地址等
            version: resData.version, // 版本号
            info: (resData.info).cast<String>(), // 更新内容介绍
            // ios是苹果应用商店地址
            iosUrl: '',
            androidUrl:''
          ),
        );
      },
    ).then((v) {
      _showFlag = false;
    });

    // 在文件末尾处修改
    await spUtil.setData(spKey, newTime.toString());
  } catch (e) {
    _showFlag = false;
  }
}
