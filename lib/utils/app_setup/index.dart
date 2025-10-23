// 初始化第三方插件
import '../../config/app_env.dart';
import '../../config/storage_config.dart';
import '../../services/vocabulary_service.dart';
import '../tool/sp_util.dart';
import 'ana_page_loop_init.dart';

void appSetupInit() {
  appEnv.init(); // 初始环境
  anaPageLoopInit();
  SpUtil.getInstance(); // 本地缓存初始化
  _initStorageConfig(); // 初始化持久化存储配置
}

/// 初始化持久化存储配置
void _initStorageConfig() async {
  try {
    // 初始化存储配置
    final storageConfig = StorageConfig();
    await storageConfig.persistentDataDirectory;
    
    // 初始化词汇服务
    final vocabularyService = VocabularyService();
    await vocabularyService.initialize();
    
    print('持久化存储配置初始化完成');
  } catch (e) {
    print('持久化存储配置初始化失败: $e');
  }
}
