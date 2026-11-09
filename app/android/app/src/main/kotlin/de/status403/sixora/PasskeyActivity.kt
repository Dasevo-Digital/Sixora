package de.status403.sixora

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.RequiresApi
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialUnknownException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialUnknownException
import androidx.credentials.exceptions.NoCredentialException
import androidx.credentials.exceptions.domerrors.InvalidStateError
import androidx.credentials.exceptions.domerrors.SecurityError
import androidx.credentials.exceptions.publickeycredential.CreatePublicKeyCredentialDomException
import androidx.credentials.exceptions.publickeycredential.GetPublicKeyCredentialDomException
import androidx.credentials.provider.CallingAppInfo
import androidx.credentials.provider.PendingIntentHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * The Sixora window of a passkey request: its own Flutter engine with the
 * Dart entry point `passkeyMain` (unlock, confirm, sign). This class says who
 * is asking, which is the part Android vouches for, and passes the answer on.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class PasskeyActivity : FlutterFragmentActivity() {
    override fun getDartEntrypointFunctionName() = "passkeyMain"

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sixora/passkeys")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> result.success(describeRequest())
                    "setIndex" -> {
                        PasskeyIndex.write(this, call.arguments as String?)
                        result.success(null)
                    }
                    "finishGet" -> {
                        result.success(null)
                        finishGet(call.arguments as String)
                    }
                    "finishCreate" -> {
                        result.success(null)
                        finishCreate(call.arguments as String)
                    }
                    "fail" -> {
                        result.success(null)
                        fail(call.arguments as String)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private val isCreate
        get() = PendingIntentHandler.retrieveProviderCreateCredentialRequest(intent) != null

    private fun describeRequest(): Map<String, Any?>? {
        PendingIntentHandler.retrieveProviderCreateCredentialRequest(intent)?.let { request ->
            val option = request.callingRequest as? CreatePublicKeyCredentialRequest ?: return null
            return describe(true, option.requestJson, option.clientDataHash, request.callingAppInfo)
        }
        PendingIntentHandler.retrieveProviderGetCredentialRequest(intent)?.let { request ->
            val option = request.credentialOptions
                .filterIsInstance<GetPublicKeyCredentialOption>()
                .firstOrNull() ?: return null
            return describe(false, option.requestJson, option.clientDataHash, request.callingAppInfo)
        }
        return null
    }

    private fun describe(
        create: Boolean,
        json: String,
        clientDataHash: ByteArray?,
        caller: CallingAppInfo,
    ): Map<String, Any?>? {
        val signers = caller.signingInfo.apkContentsSigners
        if (signers.size != 1) return null
        val certificate = MessageDigest.getInstance("SHA-256").digest(signers[0].toByteArray())
        val common = mapOf(
            "create" to create,
            "requestJson" to json,
            "package" to caller.packageName,
            "certificate" to certificate,
        )
        // Any app can claim a website address; Android leaves it to the
        // provider to believe only known browsers.
        if (!caller.isOriginPopulated()) return common
        val origin = try {
            caller.getOrigin(knownBrowsers())
        } catch (e: IllegalStateException) {
            null
        } catch (e: IllegalArgumentException) {
            null
        } ?: return common + ("refused" to true)
        return common + mapOf(
            "origin" to origin.removeSuffix("/"),
            "clientDataHash" to clientDataHash,
        )
    }

    /**
     * Browsers (package and certificate) allowed to speak for a website:
     * Google's list for Android passkey providers, release builds only. Some
     * developer builds are signed with keys that are public.
     */
    private fun knownBrowsers(): String =
        assets.open("privileged_browsers.json").bufferedReader().use { it.readText() }

    private fun finishGet(json: String) {
        val data = Intent()
        PendingIntentHandler.setGetCredentialResponse(
            data,
            GetCredentialResponse(PublicKeyCredential(json)),
        )
        setResult(RESULT_OK, data)
        finish()
    }

    private fun finishCreate(json: String) {
        val data = Intent()
        PendingIntentHandler.setCreateCredentialResponse(
            data,
            CreatePublicKeyCredentialResponse(json),
        )
        setResult(RESULT_OK, data)
        finish()
    }

    private fun fail(why: String) {
        val data = Intent()
        if (isCreate) {
            PendingIntentHandler.setCreateCredentialException(
                data,
                when (why) {
                    "cancelled" -> CreateCredentialCancellationException(why)
                    "exists" -> CreatePublicKeyCredentialDomException(InvalidStateError(), why)
                    "security" -> CreatePublicKeyCredentialDomException(SecurityError(), why)
                    else -> CreateCredentialUnknownException(why)
                },
            )
        } else {
            PendingIntentHandler.setGetCredentialException(
                data,
                when (why) {
                    "cancelled" -> GetCredentialCancellationException(why)
                    "none" -> NoCredentialException(why)
                    "security" -> GetPublicKeyCredentialDomException(SecurityError(), why)
                    else -> GetCredentialUnknownException(why)
                },
            )
        }
        setResult(RESULT_OK, data)
        finish()
    }
}
