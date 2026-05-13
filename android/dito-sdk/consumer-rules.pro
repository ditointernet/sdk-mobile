-keep class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
-keep class mobileingest.v1.** { *; }

-keep class com.connectrpc.** { *; }
-dontwarn com.connectrpc.**
