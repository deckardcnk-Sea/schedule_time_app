plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.schedule.schedule_time_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.schedule.schedule_time_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 固定签名：保证覆盖安装不丢数据（keystore 与 key.properties 随工程走）
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                val keyProps = java.util.Properties().apply {
                    keyPropsFile.inputStream().use { input -> load(input) }
                }
                signingConfigs {
                    create("release") {
                        storeFile = file(keyProps["storeFile"] as String)
                        storePassword = keyProps["storePassword"] as String
                        keyAlias = keyProps["keyAlias"] as String
                        keyPassword = keyProps["keyPassword"] as String
                    }
                }
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 无 key.properties 时退回 debug 签名（兼容首次无签名环境）
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
