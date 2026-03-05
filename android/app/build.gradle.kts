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

	compileOptions {
		targetCompatibility = JavaVersion.VERSION_17
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
