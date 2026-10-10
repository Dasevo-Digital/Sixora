package de.status403.sixora

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OtpFieldRulesTest {
    private fun otp(
        hints: List<String> = emptyList(),
        html: Map<String, String> = emptyMap(),
        vararg texts: String,
    ) = OtpFieldRules.isOtpField(hints, html, texts.toList())

    @Test
    fun hintsOfAppsAndBrowsers() {
        assertTrue(otp(hints = listOf("2faAppOTPCode")))
        assertTrue(otp(hints = listOf("smsOTPCode")))
        assertTrue(otp(html = mapOf("autocomplete" to "one-time-code")))
        assertFalse(otp(hints = listOf("password")))
        assertFalse(otp(hints = listOf("username"), texts = arrayOf("login code")))
    }

    @Test
    fun namesAndLabelsOfWebsites() {
        assertTrue(otp(html = mapOf("name" to "otp", "type" to "text")))
        assertTrue(otp(html = mapOf("id" to "app_totp", "type" to "tel")))
        assertTrue(otp(html = mapOf("name" to "mfa_code")))
        assertTrue(otp(texts = arrayOf("otpInput")))
        assertTrue(otp(texts = arrayOf("et_otp_code")))
        assertTrue(otp(html = mapOf("placeholder" to "Authentication code")))
        assertTrue(otp(texts = arrayOf("Bestätigungscode")))
        assertTrue(otp(texts = arrayOf("Sicherheitscode aus der Authenticator-App")))
        assertTrue(otp(texts = arrayOf("Código de verificación")))
        assertTrue(otp(html = mapOf("type" to "password", "name" to "totp")))
    }

    @Test
    fun otherFieldsStayAlone() {
        assertFalse(otp(html = mapOf("name" to "password", "type" to "password")))
        assertFalse(otp(html = mapOf("name" to "email", "type" to "email")))
        assertFalse(otp(html = mapOf("name" to "postal_code")))
        assertFalse(otp(texts = arrayOf("Gutscheincode")))
        assertFalse(otp(texts = arrayOf("Promo code")))
        assertFalse(otp(texts = arrayOf("Country code")))
        assertFalse(otp(texts = arrayOf("search")))
        assertFalse(otp(texts = arrayOf("hotpot recipe")))
        assertFalse(otp(html = mapOf("type" to "hidden", "name" to "otp")))
        assertFalse(otp(texts = arrayOf("Name")))
    }
}
