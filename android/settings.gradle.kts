pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // AUSBC(libausbc)发布在 JitPack
        maven("https://jitpack.io")
    }
}

rootProject.name = "UsbCaptureCard"
include(":app")
