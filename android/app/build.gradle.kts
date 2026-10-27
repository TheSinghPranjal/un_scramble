import groovy.json.JsonSlurper
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties (git-ignored).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Production Android app id lives in config/admob.json (also bundled as a
// Flutter asset). Debug and profile manifests keep Google's test app id.
// Release builds fail here if that file contains a test id or a placeholder.
val googleTestAppId = "ca-app-pub-3940256099942544~3347511713"
val admobConfigFile = rootProject.file("../config/admob.json")

fun requireReleaseAdId(key: String, pattern: Regex): String {
    if (!admobConfigFile.exists()) {
        throw org.gradle.api.GradleException(
            "Missing ${admobConfigFile}. config/admob.json must be bundled.",
        )
    }
    val parsed = JsonSlurper().parse(admobConfigFile) as Map<*, *>
    val raw = parsed[key]?.toString()?.trim().orEmpty()
    val upper = raw.uppercase()
    val blocked = raw.isEmpty() ||
        upper.contains("TODO") ||
        upper.contains("PLACEHOLDER") ||
        upper.contains("XXXX") ||
        upper.contains("NNNN") ||
        raw.contains("3940256099942544") ||
        !pattern.matches(raw)
    if (blocked) {
        throw org.gradle.api.GradleException(
            "Release AdMob id '$key' is missing, a test id, or a placeholder: '$raw'. " +
                "config/admob.json must contain this app's production Android ids.",
        )
    }
    return raw
}

val releaseAdmobAppId = requireReleaseAdId(
    "ADMOB_ANDROID_APP_ID",
    Regex("""ca-app-pub-\d{16}~\d{10}"""),
)
requireReleaseAdId("ADMOB_ANDROID_BANNER_ID", Regex("""ca-app-pub-\d{16}/\d{10}"""))
requireReleaseAdId("ADMOB_ANDROID_INTERSTITIAL_ID", Regex("""ca-app-pub-\d{16}/\d{10}"""))
requireReleaseAdId("ADMOB_ANDROID_REWARDED_ID", Regex("""ca-app-pub-\d{16}/\d{10}"""))

android {
    namespace = "com.the_lazy_bear_club.un_scramble"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.the_lazy_bear_club.un_scramble"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = googleTestAppId
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fallback so `flutter run --release` still works without the upload key.
                signingConfigs.getByName("debug")
            }
            manifestPlaceholders["admobAppId"] = releaseAdmobAppId
        }
    }
}

// Flutter's profile build type is created from debug. Pin both non-release
// types to the test app id so a later plugin change cannot copy the
// production id into profile.
afterEvaluate {
    val androidExt = extensions.getByType(com.android.build.gradle.BaseExtension::class.java)
    listOf("debug", "profile").forEach { buildTypeName ->
        androidExt.buildTypes.findByName(buildTypeName)?.manifestPlaceholders?.put(
            "admobAppId",
            googleTestAppId,
        )
    }
}

flutter {
    source = "../.."
}
