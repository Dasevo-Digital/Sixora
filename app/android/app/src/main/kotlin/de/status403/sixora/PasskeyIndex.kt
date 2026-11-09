package de.status403.sixora

import android.content.Context
import org.json.JSONException
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Base64

/**
 * Which websites have a passkey, as salted hashes: the service has to decide
 * while Sixora is locked whether to offer anything, and the app's private
 * files should not list the sites in the clear. The Dart side writes it
 * (`passkeyIndex` in sixora_core).
 */
object PasskeyIndex {
    private const val FILE = "sixora_passkeys"
    private const val ENTRY = "index"

    fun write(context: Context, json: String?) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().apply {
            if (json == null) remove(ENTRY) else putString(ENTRY, json)
        }.apply()
    }

    fun has(context: Context, rpId: String): Boolean {
        val text = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(ENTRY, null) ?: return false
        return try {
            val index = JSONObject(text)
            val wanted = siteHash(index.getString("salt"), rpId.lowercase())
            val sites = index.getJSONArray("sites")
            (0 until sites.length()).any { sites.getString(it) == wanted }
        } catch (e: JSONException) {
            false
        }
    }

    fun siteHash(salt: String, rpId: String): String = Base64.getEncoder().encodeToString(
        MessageDigest.getInstance("SHA-256").digest("$salt|$rpId".toByteArray()),
    )
}
