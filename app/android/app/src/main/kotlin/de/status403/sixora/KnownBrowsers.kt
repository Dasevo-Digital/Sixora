package de.status403.sixora

/**
 * Browsers whose website address Sixora believes. Any app can put a web
 * address into its autofill structure (a WebView, or simply made up), so a
 * fake "github.com" in some app would otherwise look like the real site and
 * its GitHub account like the right one. For all other apps only their own
 * package counts.
 *
 * Package names are unique on a device; an app posing as one of these would
 * have to be installed instead of the real browser.
 */
object KnownBrowsers {
    private val packages = setOf(
        // Chrome and Chromium
        "com.android.chrome", "com.chrome.beta", "com.chrome.dev", "com.chrome.canary",
        "org.chromium.chrome", "org.cromite.cromite", "org.bromite.bromite",
        "app.vanadium.browser", "com.kiwibrowser.browser",
        // Firefox and its forks
        "org.mozilla.firefox", "org.mozilla.firefox_beta", "org.mozilla.fenix",
        "org.mozilla.fennec_aurora", "org.mozilla.fennec_fdroid", "org.mozilla.focus",
        "org.mozilla.klar", "us.spotco.fennec_dos", "io.github.forkmaintainers.iceraven",
        "org.ironfoxoss.ironfox", "org.torproject.torbrowser",
        // Others
        "com.brave.browser", "com.brave.browser_beta", "com.brave.browser_nightly",
        "com.microsoft.emmx", "com.microsoft.emmx.beta", "com.microsoft.emmx.dev",
        "com.microsoft.emmx.canary",
        "com.opera.browser", "com.opera.browser.beta", "com.opera.gx", "com.opera.mini.native",
        "com.vivaldi.browser", "com.vivaldi.browser.snapshot",
        "com.sec.android.app.sbrowser", "com.sec.android.app.sbrowser.beta",
        "com.duckduckgo.mobile.android", "com.ecosia.android", "com.huawei.browser",
        "com.mi.globalbrowser", "com.yandex.browser",
    )

    fun isBrowser(packageName: String?) = packageName != null && packageName in packages

    /** The website to match accounts against: only when a browser asks. */
    fun trustedDomain(packageName: String?, webDomain: String?): String? =
        if (isBrowser(packageName) && !webDomain.isNullOrBlank()) webDomain.lowercase() else null
}
