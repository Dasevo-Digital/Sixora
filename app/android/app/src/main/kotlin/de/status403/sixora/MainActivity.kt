package de.status403.sixora

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import androidx.activity.result.contract.ActivityResultContracts
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
    /** Waiting for the folder picker of the automatic backup. */
    private var pendingPick: MethodChannel.Result? = null

    private val pickFolder =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
            val result = pendingPick ?: return@registerForActivityResult
            pendingPick = null
            if (uri == null) {
                result.success(null)
                return@registerForActivityResult
            }
            // Keeps the access across restarts.
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            val id = DocumentsContract.getTreeDocumentId(uri)
            result.success(mapOf("ref" to uri.toString(), "label" to id.substringAfter(':')))
        }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sixora/folder")
            .setMethodCallHandler { call, result -> folderCall(call.method, call, result) }
    }

    private fun folderCall(
        method: String,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (method == "pick") {
            pendingPick?.success(null)
            pendingPick = result
            pickFolder.launch(null)
            return
        }
        val ref = call.argument<String>("ref")
        if (ref == null || method !in setOf("write", "list", "delete")) {
            result.notImplemented()
            return
        }
        val name = call.argument<String>("name") ?: ""
        val text = call.argument<String>("text") ?: ""
        // Document providers may be slow (cloud): off the main thread.
        Thread {
            try {
                val out = folderIo(Uri.parse(ref), method, name, text)
                runOnUiThread { result.success(out) }
            } catch (e: Exception) {
                runOnUiThread { result.error("io", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    /** Files directly in the picked folder, by display name. */
    private fun children(tree: Uri): Map<String, Uri> {
        val parent = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
        val out = mutableMapOf<String, Uri>()
        contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null, null, null,
        )?.use { c ->
            while (c.moveToNext()) {
                out[c.getString(1)] = DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
            }
        }
        return out
    }

    private fun folderIo(tree: Uri, method: String, name: String, text: String): Any? {
        when (method) {
            "list" -> return children(tree).keys.toList()
            "delete" -> {
                children(tree)[name]?.let { DocumentsContract.deleteDocument(contentResolver, it) }
                return null
            }
        }
        val target = children(tree)[name] ?: DocumentsContract.createDocument(
            contentResolver,
            DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree)),
            "application/octet-stream",
            name,
        ) ?: throw IllegalStateException("Datei konnte nicht angelegt werden")
        contentResolver.openOutputStream(target, "wt")!!.use { it.write(text.toByteArray()) }
        return null
    }
}
