import 'package:flutter/material.dart';
import 'route_name.dart';
import '../pages/error_page/error_page.dart';
import '../pages/app_main/app_main.dart';
import '../pages/Login/Login.dart';
import '../pages/vocabulary/detail_page.dart';

final String initialRoute = RouteName.appMain; // 初始默认显示的路由（已去除引导页）

final Map<String,
        StatefulWidget Function(BuildContext context, {dynamic params})>
    routesData = {
  // 页面路由定义...
  RouteName.appMain: (context, {params}) => AppMain(params: params),
  RouteName.error: (context, {params}) => ErrorPage(params: params),
  RouteName.login: (context, {params}) => Login(params: params),
  RouteName.vocabularyDetail: (context, {params}) => DetailPage(
    recordId: (params as Map<String, dynamic>)['recordId'] as String,
  ),
};
