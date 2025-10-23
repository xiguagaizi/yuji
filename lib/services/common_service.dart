import '../models/common.m.dart';
import '../utils/dio/request.dart' show Request;

/// 请求示例
Future<Object> getDemo() async {
  return Request.get(
    '/m1/3617283-3245905-default/pet/1',
    queryParameters: {'corpId': 'e00fd7513077401013c0'},
  );
}

Future<Object> postDemo() async {
  return Request.post('/api', data: {});
}

Future<Object> putDemo() async {
  return Request.put('/api', data: {});
}

/// 获取APP最新版本号, 演示更新APP组件
Future<NewVersionData> getNewVersion() async {
  // TODO: 替换为你的真实请求接口，并返回数据，此处演示直接返回数据
  // var res = await Request.get(
  //   '/api',
  //   queryParameters: {'key': 'value'},
  // ).catchError((e) => resData);
  var resData = NewVersionRes.fromJson({
    "code": "0",
    "message": "success",
    "data": {
      "version": "1.0.0",
      "info": ["修复bug提升性能", "测试功能"]
    }
  });
  return (resData.data ?? {}) as NewVersionData;
}
