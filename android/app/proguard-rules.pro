# Flutter Engine and Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Application Package
-keep class com.opensoftwares.crm.** { *; }
-keep class com.opensoftwares.crm.MainActivity { *; }

# Firebase
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Supabase & Gson & Network
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-dontwarn javax.annotation.**
