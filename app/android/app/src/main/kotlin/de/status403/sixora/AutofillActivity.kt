package de.status403.sixora

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.WindowManager
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The small Sixora window behind "Code aus Sixora einfügen": its own
 * Flutter engine with the Dart entry point `autofillMain` (unlock, pick the
 * account). The chosen code goes back to Android as the filled dataset.
 */
@RequiresApi(Build.VERSION_CODES.O)
class AutofillActivity : FlutterFragmentActivity() {
    override fun getDartEntrypointFunctionName() = "autofillMain"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Codes never show up in screenshots or the app switcher.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sixora/autofill")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> result.success(
                        mapOf(
                            "domain" to intent.getStringExtra(EXTRA_DOMAIN),
                            "package" to intent.getStringExtra(EXTRA_PACKAGE),
                        ),
                    )
                    "fill" -> {
                        result.success(null)
                        fill(call.arguments as String)
                    }
                    "cancel" -> {
                        result.success(null)
                        setResult(RESULT_CANCELED)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun fill(code: String) {
        val dataset = Dataset.Builder(SixoraAutofillService.presentation(this))
        for (id in fieldIds()) dataset.setValue(id, AutofillValue.forText(code))
        setResult(
            RESULT_OK,
            Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset.build()),
        )
        finish()
    }

    private fun fieldIds(): List<AutofillId> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(EXTRA_IDS, AutofillId::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(EXTRA_IDS)
        } ?: emptyList()

    companion object {
        const val EXTRA_IDS = "de.status403.sixora.autofill.IDS"
        const val EXTRA_DOMAIN = "de.status403.sixora.autofill.DOMAIN"
        const val EXTRA_PACKAGE = "de.status403.sixora.autofill.PACKAGE"
    }
}
