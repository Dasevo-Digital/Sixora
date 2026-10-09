package de.status403.sixora

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required for the biometric prompt.
 * The channel `sixora/window` blocks screenshots and screen recordings
 * (FLAG_SECURE) unless the user allows them; it is set before the first
 * frame, so the codes never show up in the recent apps preview.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sixora/window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Codes are marked sensitive: the clipboard preview and keyboards
        // show dots instead of the code (Android 13+, also honoured by many
        // keyboards on older versions).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sixora/clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "copySensitive") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text") ?: ""
                val clip = ClipData.newPlainText("Sixora", text)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    clip.description.extras = PersistableBundle().apply {
                        putBoolean("android.content.extra.IS_SENSITIVE", true)
                    }
                }
                val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                manager.setPrimaryClip(clip)
                result.success(null)
            }
    }
}
