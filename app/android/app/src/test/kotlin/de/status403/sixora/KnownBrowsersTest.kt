package de.status403.sixora

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class KnownBrowsersTest {
    @Test
    fun browsersReportTheWebsite() {
        assertEquals("github.com", KnownBrowsers.trustedDomain("org.mozilla.firefox", "GitHub.com"))
        assertEquals("github.com", KnownBrowsers.trustedDomain("com.android.chrome", "github.com"))
    }

    @Test
    fun otherAppsCannotClaimAWebsite() {
        assertNull(KnownBrowsers.trustedDomain("com.example.game", "github.com"))
        assertNull(KnownBrowsers.trustedDomain(null, "github.com"))
    }

    @Test
    fun noWebsiteWithoutADomain() {
        assertNull(KnownBrowsers.trustedDomain("org.mozilla.firefox", null))
        assertNull(KnownBrowsers.trustedDomain("org.mozilla.firefox", " "))
    }
}
