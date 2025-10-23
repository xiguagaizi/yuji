# 📱 Android 真机调试完整指南

## 一、手机端设置（必须完成）

### 1. 开启开发者选项
1. 打开手机 **设置**
2. 找到 **关于手机**（可能在"系统"或"我的设备"中）
3. 找到 **版本号**（MIUI版本号/Android版本号）
4. **连续快速点击 7 次** 版本号
5. 看到提示"您已处于开发者模式"或"开发者选项已开启"

### 2. 开启 USB 调试
1. 返回 **设置** 主页
2. 找到 **更多设置** 或 **系统** → **开发者选项**
3. 开启以下选项：
   - ✅ **USB 调试**（必须）
   - ✅ **USB 安装**（建议）
   - ✅ **USB 调试（安全设置）**（如果有）
   - ✅ **停用权限监控**（可选，可以减少调试时的权限提示）

### 3. 连接电脑
1. 使用 **原装数据线** 或质量好的数据线连接手机和电脑
   - ⚠️ 注意：很多充电线不支持数据传输
2. 手机上选择 **文件传输（MTP）** 模式或 **传输文件** 模式
3. 会弹出 **允许 USB 调试** 的提示框：
   - 勾选 **一律允许使用这台计算机进行调试**
   - 点击 **允许** 或 **确定**

---

## 二、电脑端设置

### 方法 1：使用 Flutter SDK 自带的 ADB（推荐）

Flutter SDK 已经包含了 ADB 工具，路径通常在：
```
C:\Users\你的用户名\AppData\Local\Android\Sdk\platform-tools\adb.exe
```

**添加到系统环境变量：**

1. 按 `Win + R`，输入 `sysdm.cpl` 回车
2. 点击 **高级** → **环境变量**
3. 在 **系统变量** 中找到 **Path**，点击 **编辑**
4. 点击 **新建**，添加以下路径（根据实际情况修改）：
   ```
   C:\Users\你的用户名\AppData\Local\Android\Sdk\platform-tools
   ```
5. 点击 **确定** 保存
6. **重新打开命令提示符** 或 PowerShell

### 方法 2：查找 Flutter 的 ADB 位置

打开 PowerShell 或命令提示符，运行：
```powershell
flutter doctor -v
```

输出中会显示 Android SDK 的位置，例如：
```
Android SDK at C:\Users\xxx\AppData\Local\Android\Sdk
```

然后 ADB 就在该目录的 `platform-tools` 子目录中。

---

## 三、验证连接

### 1. 检查 ADB 是否可用

打开新的命令提示符或 PowerShell，运行：
```bash
adb version
```

如果显示版本信息，说明 ADB 配置成功。

### 2. 查看连接的设备

```bash
adb devices
```

**正常输出示例：**
```
List of devices attached
XXXXXXXXXX      device
```

**可能遇到的情况：**

| 输出 | 说明 | 解决方法 |
|------|------|----------|
| `List of devices attached`（空） | 未检测到设备 | 检查数据线、USB调试是否开启、驱动是否安装 |
| `XXXXXXXXXX    unauthorized` | 未授权 | 在手机上点击"允许USB调试" |
| `XXXXXXXXXX    offline` | 设备离线 | 拔掉重插数据线，或运行 `adb kill-server` 后重试 |
| `XXXXXXXXXX    device` | ✅ 正常连接 | 可以开始调试了！ |

### 3. 重启 ADB 服务（如果遇到问题）

```bash
# 停止 ADB 服务
adb kill-server

# 启动 ADB 服务
adb start-server

# 再次查看设备
adb devices
```

### 4. 检查 Flutter 是否识别设备

```bash
flutter devices
```

**正常输出示例：**
```
Found 4 connected devices:
  Mi 10 (mobile) • XXXXXXXXXX • android-arm64  • Android 12 (API 31)
  Windows (desktop) • windows • windows-x64    • Microsoft Windows
  Chrome (web)      • chrome  • web-javascript • Google Chrome
  Edge (web)        • edge    • web-javascript • Microsoft Edge
```

如果能看到你的手机设备，说明一切正常！✅

---

## 四、运行 Flutter 应用到真机

### 方法 1：使用命令行

在项目目录 `d:\my_little_apk\yueyu` 下运行：

```bash
# 运行到连接的设备（如果只有一个设备）
flutter run

# 指定设备运行（如果有多个设备）
flutter run -d 设备ID

# 运行 Release 版本（性能更好）
flutter run --release
```

### 方法 2：使用 VS Code

1. 确保设备已连接并被识别
2. 打开 VS Code
3. 按 `F5` 或点击 **运行 → 启动调试**
4. VS Code 右下角会显示当前选择的设备
5. 点击设备名可以切换设备

### 方法 3：构建 APK 安装包

```bash
# 构建 Release APK
flutter build apk --release

# 构建后 APK 位置：
# build/app/outputs/flutter-apk/app-release.apk
```

然后手动传输到手机安装。

---

## 五、常见问题排查

### ❌ 问题 1：`adb` 不是内部或外部命令

**原因：** ADB 未添加到系统环境变量

**解决：**
1. 找到 Android SDK 的 `platform-tools` 目录
2. 添加到系统 PATH 环境变量（参考上面的步骤）
3. 重新打开命令行窗口

### ❌ 问题 2：设备显示 `unauthorized`

**原因：** 手机未授权 USB 调试

**解决：**
1. 检查手机屏幕是否有授权提示
2. 如果没有，运行 `adb kill-server` 后重新连接
3. 在手机上勾选"一律允许"并点击"允许"

### ❌ 问题 3：设备显示 `offline`

**原因：** ADB 连接异常

**解决：**
```bash
adb kill-server
adb start-server
adb devices
```

### ❌ 问题 4：手机驱动未安装（Windows）

**现象：** 设备管理器中设备显示黄色感叹号

**解决：**
1. 下载安装手机厂商的 USB 驱动程序：
   - 小米：小米助手
   - 华为：HiSuite
   - OPPO/vivo：官方 PC 套件
   - 三星：Samsung Smart Switch
2. 或者安装通用 Android 驱动

### ❌ 问题 5：`flutter run` 卡住不动

**可能原因：**
- Gradle 下载依赖较慢
- 网络问题

**解决：**
1. 等待一段时间（首次运行可能需要 10-30 分钟）
2. 配置 Gradle 国内镜像（修改 `android/build.gradle`）
3. 使用 VPN 或代理

### ❌ 问题 6：应用安装失败

**常见错误：**
- `INSTALL_FAILED_INSUFFICIENT_STORAGE`：存储空间不足
- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`：卸载旧版本后重试
- `INSTALL_FAILED_INVALID_APK`：APK 损坏，重新构建

---

## 六、调试技巧

### 1. 查看实时日志

```bash
flutter logs
```

或使用 ADB：
```bash
adb logcat
```

### 2. 热重载（Hot Reload）

运行 `flutter run` 后，在命令行按：
- **`r`** - 热重载（保持应用状态）
- **`R`** - 热重启（重新启动应用）
- **`q`** - 退出

### 3. 使用 Flutter DevTools

```bash
# 启动 DevTools
flutter pub global activate devtools
flutter pub global run devtools

# 或直接在应用运行时打开
# 运行 flutter run 后会显示 DevTools 的链接
```

### 4. 性能模式标识

在应用右上角：
- **DEBUG** 横幅 = 调试模式（性能较差，有热重载）
- 无横幅 = Release 模式（性能最佳，用于测试真实性能）

---

## 七、快速开始调试

**一键检查清单：**

```bash
# 1. 检查设备连接
adb devices

# 2. 检查 Flutter 识别
flutter devices

# 3. 运行应用
flutter run

# 4. 如果遇到问题，重启 ADB
adb kill-server && adb start-server && adb devices
```

---

## 八、项目特定配置

本项目（yueyu）使用的权限：
- 📱 录音权限（RECORD_AUDIO）
- 💾 存储权限（READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE）
- 🌐 网络权限（INTERNET）

首次运行时会请求这些权限，请在手机上允许。

---

## 📞 需要帮助？

如果按照以上步骤仍然无法调试，请检查：
1. ✅ 手机 USB 调试已开启
2. ✅ 使用了支持数据传输的数据线
3. ✅ 已在手机上授权此电脑
4. ✅ ADB 已添加到环境变量
5. ✅ 手机驱动已正确安装

如果问题依然存在，可以运行以下命令获取诊断信息：
```bash
flutter doctor -v
```





