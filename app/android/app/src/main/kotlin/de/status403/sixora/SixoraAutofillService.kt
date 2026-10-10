package de.status403.sixora

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.view.View
import android.view.autofill.AutofillId
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import java.util.concurrent.atomic.AtomicInteger

/**
 * Offers "Code aus Sixora einfügen" in one-time code fields of other apps
 * and websites. It knows no codes itself: the vault may be locked, and the
 * codes never leave the app's memory. Tapping the suggestion opens
 * [AutofillActivity], which unlocks, lets the user pick the account and
 * returns the filled dataset.
 */
@RequiresApi(Build.VERSION_CODES.O)
class SixoraAutofillService : AutofillService() {
    private val requests = AtomicInteger()

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure
        val target = structure?.activityComponent?.packageName
        if (structure == null || target == null || target == packageName) {
            callback.onSuccess(null)
            return
        }
        val found = findOtpFields(structure)
        if (found.ids.isEmpty()) {
            callback.onSuccess(null)
            return
        }
        val intent = Intent(this, AutofillActivity::class.java)
            .putParcelableArrayListExtra(AutofillActivity.EXTRA_IDS, ArrayList(found.ids))
            .putExtra(AutofillActivity.EXTRA_DOMAIN, found.domain)
            .putExtra(AutofillActivity.EXTRA_PACKAGE, target)
        // Mutable: Android adds the form's structure to the intent.
        val flags = PendingIntent.FLAG_CANCEL_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        val pending = PendingIntent.getActivity(this, requests.incrementAndGet(), intent, flags)
        val dataset = Dataset.Builder(presentation(this))
        for (id in found.ids) dataset.setValue(id, null)
        dataset.setAuthentication(pending.intentSender)
        callback.onSuccess(FillResponse.Builder().addDataset(dataset.build()).build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private class Found(val ids: List<AutofillId>, val domain: String?)

    private fun findOtpFields(structure: AssistStructure): Found {
        val ids = mutableListOf<AutofillId>()
        var domain: String? = null
        fun visit(node: AssistStructure.ViewNode) {
            if (domain == null && !node.webDomain.isNullOrEmpty()) domain = node.webDomain
            val id = node.autofillId
            if (id != null && node.autofillType == View.AUTOFILL_TYPE_TEXT &&
                node.visibility == View.VISIBLE && isOtp(node)
            ) {
                ids += id
            }
            for (i in 0 until node.childCount) visit(node.getChildAt(i))
        }
        for (i in 0 until structure.windowNodeCount) visit(structure.getWindowNodeAt(i).rootViewNode)
        return Found(ids, domain)
    }

    private fun isOtp(node: AssistStructure.ViewNode): Boolean {
        val html = node.htmlInfo?.attributes
            ?.associate { it.first.lowercase() to it.second }
            ?: emptyMap()
        val texts = listOfNotNull(
            node.idEntry,
            node.hint?.toString(),
            node.contentDescription?.toString(),
        )
        return OtpFieldRules.isOtpField(node.autofillHints?.toList() ?: emptyList(), html, texts)
    }

    companion object {
        /** The suggestion as shown under the field. */
        fun presentation(context: android.content.Context) =
            RemoteViews(context.packageName, R.layout.autofill_item).apply {
                setTextViewText(R.id.autofill_text, context.getString(R.string.autofill_insert))
            }
    }
}
