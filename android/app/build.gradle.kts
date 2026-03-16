import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
	id("com.android.application")
	id("kotlin-android")
	// The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
	id("dev.flutter.flutter-gradle-plugin")
}

android {
	namespace = "com.technicjelle.simple_audio_converter"
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
		applicationId = "com.technicjelle.simple_audio_converter"
		// You can update the following values to match your application needs.
		// For more information, see: https://flutter.dev/to/review-gradle-config.
		minSdk = flutter.minSdkVersion
		targetSdk = flutter.targetSdkVersion
		versionCode = flutter.versionCode
		versionName = flutter.versionName
	}

	buildTypes {
		release {
			// TODO: Add your own signing config for the release build.
			// Signing with the debug keys for now, so `flutter run --release` works.
			signingConfig = signingConfigs.getByName("debug")

			// Enables code-related app optimization.
			isMinifyEnabled = true

			// Enables resource shrinking.
			isShrinkResources = true

			proguardFiles(
				// Default file with automatically generated optimization rules.
				getDefaultProguardFile("proguard-android-optimize.txt"),
				"proguard-rules.pro"
			)
		}
	}
}

flutter {
	source = "../.."
}

//Source: https://github.com/saber-notes/saber/blob/c50bdb0fdd0ad02e963171a9cf8b6d2214542832/android/app/build.gradle.kts#L76-L85
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
	val variant = this
	variant.outputs.forEach { output ->
		val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
		if (abiVersionCode != null) {
			(output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
		}
	}
}
