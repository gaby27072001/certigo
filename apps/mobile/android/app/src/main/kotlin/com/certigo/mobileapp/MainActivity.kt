package com.certigo.mobileapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.certigo.mobileapp/notifications").setMethodCallHandler { call, result ->
            if (call.method == "openSettings") {
                try {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(true)
                } catch (error: android.content.ActivityNotFoundException) {
                    result.error("settings_unavailable", "Notification settings unavailable", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
