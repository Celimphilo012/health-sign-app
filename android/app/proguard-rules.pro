# Flutter Play Store split (suppress missing class errors)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# TFLite
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Camera
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# App
-keep class com.healthsign.health_sign_app.** { *; }