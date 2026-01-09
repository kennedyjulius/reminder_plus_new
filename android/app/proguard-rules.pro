# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase specific rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# WorkManager specific rules
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Notification specific rules
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }

# Google Sign-In specific rules
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep all classes in the main package
-keep class com.reminder.reminderplus.** { *; }

# Keep all classes that might be used by plugins
-keep class * extends io.flutter.plugin.common.PluginRegistry$Registrar
-keep class * extends io.flutter.plugin.common.MethodCallHandler
-keep class * extends io.flutter.plugin.common.EventChannel$StreamHandler
-keep class * extends io.flutter.plugin.common.BasicMessageChannel$MessageHandler

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep all classes with @Keep annotation
-keep @androidx.annotation.Keep class * { *; }

# Google Play Core specific rules
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ML Kit specific rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Flutter deferred components
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
