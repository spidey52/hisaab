import java.io.FileInputStream
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val allowDevelopmentReleaseSigning =
    providers.gradleProperty("allowDevelopmentReleaseSigning").orNull == "true"

fun decodedDartDefines(): Map<String, String> =
    providers.gradleProperty("dart-defines").orNull
        ?.split(",")
        ?.mapNotNull { encoded ->
            runCatching {
                String(
                    Base64.getDecoder().decode(encoded),
                    StandardCharsets.UTF_8,
                )
            }.getOrNull()
        }
        ?.mapNotNull { definition ->
            val separator = definition.indexOf('=')
            if (separator <= 0) {
                null
            } else {
                definition.substring(0, separator) to
                    definition.substring(separator + 1)
            }
        }
        ?.toMap()
        .orEmpty()

fun isPrivateReleaseHost(hostValue: String): Boolean {
    val host = hostValue.lowercase().removePrefix("[").removeSuffix("]")
    val isIpv6Literal = host.contains(":")
    if (
        host == "localhost" ||
        host.endsWith(".localhost") ||
        host.endsWith(".local") ||
        host.endsWith(".ts.net") ||
        host == "::" ||
        host == "::1" ||
        host.startsWith("::ffff:") ||
        (
            isIpv6Literal &&
                (
                    host.startsWith("fc") ||
                        host.startsWith("fd") ||
                        Regex("^fe[89ab]").containsMatchIn(host) ||
                        host.startsWith("ff")
                )
        )
    ) {
        return true
    }

    val octets = host.split(".").mapNotNull(String::toIntOrNull)
    if (octets.size != 4) return false
    return octets[0] == 0 ||
        octets[0] == 10 ||
        octets[0] == 127 ||
        (octets[0] == 100 && octets[1] in 64..127) ||
        (octets[0] == 169 && octets[1] == 254) ||
        (octets[0] == 172 && octets[1] in 16..31) ||
        (octets[0] == 192 && octets[1] == 168) ||
        octets[0] >= 224
}

if (releaseRequested) {
    val releaseApiUrl = decodedDartDefines()["HISAAB_API_URL"]
    val releaseApiUri = releaseApiUrl?.let { runCatching { URI(it) }.getOrNull() }
    val hasInvalidReleaseHost =
        releaseApiUri?.host?.let(::isPrivateReleaseHost) ?: true
    val hasInvalidReleasePath =
        releaseApiUri?.rawPath?.let { it.isNotEmpty() && it != "/" } ?: true
    if (
        releaseApiUri?.scheme != "https" ||
        releaseApiUri?.host.isNullOrBlank() ||
        hasInvalidReleaseHost ||
        hasInvalidReleasePath ||
        !releaseApiUri?.userInfo.isNullOrEmpty() ||
        !releaseApiUri?.rawQuery.isNullOrEmpty() ||
        !releaseApiUri?.rawFragment.isNullOrEmpty()
    ) {
        throw GradleException(
            "Release builds require a public HTTPS API origin. Pass " +
                "--dart-define=HISAAB_API_URL=https://your-production-host.",
        )
    }
}

if (releaseRequested && !hasReleaseSigning && !allowDevelopmentReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Copy key.properties.example to " +
            "android/key.properties and add your upload-keystore details.",
    )
}

android {
    namespace = "com.hisaab.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hisaab.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(
                    keystoreProperties["storeFile"] as String,
                )
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else if (allowDevelopmentReleaseSigning) {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
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
