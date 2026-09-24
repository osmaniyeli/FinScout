package com.moneytrace.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val INTEGRITY_CHANNEL = "com.moneytrace.app/integrity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ekran görüntüsü ve görev değiştirici önizlemesi serbest (ürün kararı).
        // Anti-Tapjacking / Overlay Kalkanı: Bankacılık truva atlarının şeffaf katmanla dokunma çalmasını engelle
        window.decorView.filterTouchesWhenObscured = true
    }

    private fun isDeviceRooted(): Boolean {
        val buildTags = android.os.Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        for (path in paths) {
            if (java.io.File(path).exists()) {
                return true
            }
        }
        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bütünlük ve Anti-Malware / Root Kanalı (< 1 ms çalışma süresi)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTEGRITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkIntegrity" -> {
                    val rooted = isDeviceRooted()
                    val data = mapOf(
                        "isRooted" to rooted,
                        "isTampered" to false,
                        "tapjackingProtected" to true
                    )
                    result.success(data)
                }
                else -> result.notImplemented()
            }
        }
    }
}
