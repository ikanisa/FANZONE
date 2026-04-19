# Project-specific production keep rules.
# Flutter and plugin defaults are supplied by the Android Gradle plugin.

# ── Firebase ──
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Messaging ──
-keep class com.google.firebase.messaging.** { *; }
-keepclassmembers class * extends com.google.firebase.messaging.FirebaseMessagingService {
    public void onMessageReceived(com.google.firebase.messaging.RemoteMessage);
    public void onNewToken(java.lang.String);
}

# ── Flutter ──
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# ── Supabase / GoTrue ──
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ── Kotlin serialization (used by some plugins) ──
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
