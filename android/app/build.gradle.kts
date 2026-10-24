plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.chenjinghao.usbcapturecard"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.chenjinghao.usbcapturecard"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    // AUSBC:libuvc 封装,USB 权限/热插拔/MJPEG 预览/UAC 音频/MP4 录制
    // 注意:JitPack 上 3.2.8 起的所有版本(含 3.3.x)发布损坏(libnative 二进制 404),
    // 3.2.7 是最后一个完整可用版本(已核对 maven-metadata 与 AAR 200)。
    // immersionbar / webpdecoder 在 JitPack 上已 401 下架;libausbc 源码对二者
    // 零引用(仅 BaseApplication/图片加载器路径,本项目不走),安全排除。
    implementation("com.github.jiangdongguo.AndroidUSBCamera:libausbc:3.2.7") {
        exclude(group = "com.gyf.immersionbar")
        exclude(group = "com.zlc.glide")
    }
    // libausbc 对 libuvc 是 implementation 依赖,pom 不导出,须显式引入
    // (com.serenegiant.usb.USBMonitor / UVCCamera 在此模块)
    implementation("com.github.jiangdongguo.AndroidUSBCamera:libuvc:3.2.7")

    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.1")
}
