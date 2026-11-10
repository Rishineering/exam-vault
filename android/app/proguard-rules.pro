# ML Kit text recognition references optional script recognizers (Chinese,
# Devanagari, Japanese, Korean) that are not bundled when only the Latin
# recognizer is used. Suppress R8's missing-class warnings for them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep the ML Kit text recognition entry points used by the Flutter plugin.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
