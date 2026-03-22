## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

## Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

## Background Geolocation
-keep class com.transistorsoft.** { *; }
-dontwarn com.transistorsoft.**

## Mapbox
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

## Hive
-keep class com.hive.** { *; }
-keepclassmembers class * implements com.hive.HiveObject { *; }
