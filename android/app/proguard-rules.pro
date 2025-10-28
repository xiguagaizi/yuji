# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep audio related classes
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }

# Keep file picker classes
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep permission handler classes
-keep class com.baseflow.permissionhandler.** { *; }

# Keep device info classes
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Keep package info classes
-keep class dev.fluttercommunity.plus.package_info.** { *; }

# Keep shared preferences classes
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep URL launcher classes
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep toast classes
-keep class io.github.ponnamkarthik.toast.fluttertoast.** { *; }

# Keep record classes
-keep class com.llfbandit.record.** { *; }

# Keep path provider classes
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep open file classes
-keep class com.crazecoder.openfile.** { *; }

# Keep OTA update classes
-keep class com.ota_update.** { *; }




