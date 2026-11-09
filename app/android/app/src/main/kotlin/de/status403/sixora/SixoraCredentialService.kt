package de.status403.sixora

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.os.OutcomeReceiver
import androidx.annotation.RequiresApi
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.provider.BeginCreateCredentialRequest
import androidx.credentials.provider.BeginCreateCredentialResponse
import androidx.credentials.provider.BeginCreatePublicKeyCredentialRequest
import androidx.credentials.provider.BeginGetCredentialRequest
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.BeginGetPublicKeyCredentialOption
import androidx.credentials.provider.CreateEntry
import androidx.credentials.provider.CredentialEntry
import androidx.credentials.provider.CredentialProviderService
import androidx.credentials.provider.ProviderClearCredentialStateRequest
import androidx.credentials.provider.PublicKeyCredentialEntry
import org.json.JSONException
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicInteger

/**
 * Sixora as a passkey provider of Android 14 and later. Like the autofill
 * service it knows no secrets: the vault may be locked. It only says whether
 * there is something to offer; [PasskeyActivity] unlocks, checks who asks
 * and signs.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class SixoraCredentialService : CredentialProviderService() {
    private val requests = AtomicInteger()

    private fun window(): PendingIntent = PendingIntent.getActivity(
        this,
        requests.incrementAndGet(),
        Intent(this, PasskeyActivity::class.java).setPackage(packageName),
        // Android adds the request to this intent.
        PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    override fun onBeginCreateCredentialRequest(
        request: BeginCreateCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginCreateCredentialResponse, CreateCredentialException>,
    ) {
        val entries = if (request is BeginCreatePublicKeyCredentialRequest) {
            listOf(CreateEntry.Builder(getString(R.string.app_name), window()).build())
        } else {
            emptyList()
        }
        callback.onResult(BeginCreateCredentialResponse.Builder().setCreateEntries(entries).build())
    }

    override fun onBeginGetCredentialRequest(
        request: BeginGetCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginGetCredentialResponse, GetCredentialException>,
    ) {
        val entries = ArrayList<CredentialEntry>()
        for (option in request.beginGetCredentialOptions) {
            if (option !is BeginGetPublicKeyCredentialOption) continue
            val rpId = try {
                JSONObject(option.requestJson).optString("rpId")
            } catch (e: JSONException) {
                ""
            }
            if (rpId.isEmpty() || !PasskeyIndex.has(this, rpId)) continue
            entries += PublicKeyCredentialEntry.Builder(
                this,
                getString(R.string.passkey_entry),
                window(),
                option,
            ).build()
        }
        callback.onResult(BeginGetCredentialResponse.Builder().setCredentialEntries(entries).build())
    }

    override fun onClearCredentialStateRequest(
        request: ProviderClearCredentialStateRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<Void?, ClearCredentialException>,
    ) {
        callback.onResult(null)
    }
}
