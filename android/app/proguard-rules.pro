# Preserve Kotlin types looked up by name by shared_preferences' JNI bridge.
# https://github.com/flutter/packages/blob/main/packages/pigeon/native_interop_guide.md#step-5-android-release-build-configuration-jni
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
