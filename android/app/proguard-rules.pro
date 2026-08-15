# R8 / ProGuard rules for BNI 121 Conclave.
#
# R8 strips and renames anything it cannot prove is used. Everything reached by
# reflection, JNI, or a platform callback is invisible to that analysis, so it
# gets removed — and the app then fails only in a RELEASE build, usually at the
# venue. Each rule below names the thing that actually breaks without it.

# ---------------------------------------------------------------------------
# Flutter
# ---------------------------------------------------------------------------
# The engine calls into these from C++ via JNI; R8 sees no Java caller.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ---------------------------------------------------------------------------
# Firebase / Google Play Services
# ---------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore and FCM deserialise into model classes reflectively. Renamed fields
# silently stop matching the document, so values arrive null rather than
# throwing — a corrupted read that looks like missing data.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations
-keepattributes AnnotationDefault

# ---------------------------------------------------------------------------
# ML Kit barcode scanning (mobile_scanner) — the captain's QR scanner
# ---------------------------------------------------------------------------
# Loaded dynamically by Play Services. Strip these and scanning fails on a real
# device, in release only, in a room full of people.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# mobile_scanner probes for both the bundled and the Play-Services-delivered ML
# Kit model and picks whichever is present. Only one is compiled in, so R8 warns
# about the other — that is expected, not a problem.
-dontwarn com.google.mlkit.vision.barcode.internal.**

# ---------------------------------------------------------------------------
# sqflite — the offline record of the entire event
# ---------------------------------------------------------------------------
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ---------------------------------------------------------------------------
# Razorpay — the registration-fee checkout
# ---------------------------------------------------------------------------
# The SDK drives its checkout through a WebView JavaScript bridge and reads
# @JavascriptInterface-annotated callbacks by name, plus proguard.annotation.*
# markers on its own classes. R8 stripping any of these breaks payment only in a
# release build — money on the line, at registration time. Razorpay's official
# consumer rules:
-keep class com.razorpay.** { *; }
-keep class proguard.annotation.** { *; }
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
# Razorpay pulls in Google Pay's API for UPI; it's optional and may be absent.
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**

# ---------------------------------------------------------------------------
# Play Core + Play app-update (in_app_update)
# ---------------------------------------------------------------------------
# Flutter references Play Core for split installs even when unused, and
# in_app_update drives the forced-update flow through com.google.android.play.*.
# Without the -dontwarn, R8 fails the build on the missing classes; without the
# keep, the update flow breaks in release only.
-dontwarn com.google.android.play.**
-keep class com.google.android.play.** { *; }

# ---------------------------------------------------------------------------
# Kotlin
# ---------------------------------------------------------------------------
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }

# ---------------------------------------------------------------------------
# OkHttp / Okio (transitive: Firebase, ML Kit)
# ---------------------------------------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
# Keep line numbers so a production stack trace names a real line, then hide the
# original file name. Without SourceFile kept, every frame reads "Unknown
# Source" and a crash report is worthless.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Native methods are called from C++ by name.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Enum valueOf/values are used reflectively by serialisation.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable CREATOR is looked up by name at runtime.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
