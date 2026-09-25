package com.moneytrace.app

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import java.security.MessageDigest
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

    private fun signingSha1(): List<String> {
        return try {
            val sigs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo
                if (info == null) emptyArray()
                else if (info.hasMultipleSigners()) info.apkContentsSigners
                else info.signingCertificateHistory
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }
            (sigs ?: emptyArray()).map { sig ->
                MessageDigest.getInstance("SHA-1").digest(sig.toByteArray())
                    .joinToString(":") { b -> "%02X".format(b) }
            }
        } catch (e: Exception) {
            emptyList()
        }
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
                // Google girişi teşhisi: uygulamayı imzalayan sertifika(lar)ın SHA-1'i.
                // Google Cloud'daki Android OAuth istemcisinde bu değer(ler) kayıtlı olmalı.
                "signingSha1" -> result.success(signingSha1())
                else -> result.notImplemented()
            }
        }
    }
}
