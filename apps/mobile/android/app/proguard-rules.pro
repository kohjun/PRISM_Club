# ProGuard / R8 rules for PRISM Club mobile.
#
# This file is consumed when `minifyEnabled = true` in app/build.gradle.kts
# (currently OFF for safer release builds; flip on once symbol upload to
# Crashlytics is verified in a staging cut). When minification IS on, the
# rules below keep the bytecode tags Crashlytics needs to symbolicate
# stack traces in the console.

# Preserve source-file + line-number attributes so Crashlytics frames can
# be mapped back to the original Dart/Kotlin source. The
# `-renamesourcefileattribute` strips the actual file path so we don't
# leak local CI build paths into the symbolicated trace.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Firebase Crashlytics + Analytics ship their own consumer rules via the
# Gradle plugin / Android library AAR; no additional -keep is needed
# for typical Flutter usage. Add per-feature -keep rules here when a
# native plugin reports stripped classes in release crashes.
