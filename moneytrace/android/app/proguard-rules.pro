# Flutter Proguard Rules for Paraİz (MoneyTrace)

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Sqflite SQLite Database preservation
-keep class com.tekartik.sqflite.** { *; }

# File Picker preservation
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Path Provider preservation
-keep class io.flutter.plugins.pathprovider.** { *; }

# Biyometrik kilit (local_auth / androidx.biometric)
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }

# Zamanlanmış bildirimler (flutter_local_notifications, Gson ile serileştirir)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Güvenli depolama (flutter_secure_storage)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Don't warn on missing references in third party libraries
-dontwarn io.flutter.**
-dontwarn com.tekartik.sqflite.**
