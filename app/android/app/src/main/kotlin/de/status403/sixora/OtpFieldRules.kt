package de.status403.sixora

/**
 * Decides whether an input field asks for a one-time code. Plain logic over
 * what the autofill structure tells about the field (hints, HTML attributes,
 * id and label), so it is tested without Android.
 *
 * Sixora only offers itself in such fields: as autofill service it sees
 * every form, and a suggestion in a name or password field would be noise.
 */
object OtpFieldRules {
    /** Autofill hints of apps (androidx HintConstants) and browsers. */
    private val otpHints = setOf("smsotpcode", "2faappotpcode", "one-time-code", "onetimecode", "otp")

    /** Hints of other kinds of fields. */
    private val otherHints = setOf(
        "username", "password", "current-password", "new-password", "email", "emailaddress",
        "phone", "tel", "phonenumber", "postalcode", "postal-code", "creditcardnumber",
        "cc-number", "cc-csc", "creditcardsecuritycode", "name", "personname", "address",
        "street-address", "postaladdress",
    )

    /** HTML input types that never take a code. */
    private val nonText = setOf(
        "email", "hidden", "checkbox", "radio", "submit", "button", "search", "url",
        "date", "file", "color", "range",
    )

    /** Words that on their own mean a one-time code. */
    private val strong = listOf(
        "totp", "2fa", "mfa", "tfa", "one-time", "onetime", "one_time", "authenticator",
        "two-factor", "twofactor", "two_factor", "2-step", "two-step", "2step", "zwei-faktor",
        "einmalcode", "einmal-code", "einmalpasswort", "un solo uso", "dos pasos",
    )

    /** "code" counts together with one of these. */
    private val codeContext = listOf(
        "verif", "auth", "secur", "confirm", "login", "sign-in", "signin", "bestätig",
        "bestaetig", "sicherheit", "anmelde", "verifizier", "authentifizier", "seguridad",
        "acceso",
    )

    /** Codes of other kinds. */
    private val otherCodes = listOf(
        "postal", "zip", "plz", "promo", "coupon", "voucher", "gutschein", "rabatt",
        "discount", "country", "area", "invite", "einladung", "referral", "captcha",
        "cupón", "cupon", "descuento",
    )

    private val otpWord = Regex("(^|[^a-z0-9])otp")

    fun isOtpField(hints: List<String>, html: Map<String, String>, texts: List<String>): Boolean {
        val hintSet = hints.map { it.lowercase().trim() }.toSet()
        val autocomplete = html["autocomplete"]?.lowercase()?.split(' ')?.toSet() ?: emptySet()
        if (hintSet.any { it in otpHints } || "one-time-code" in autocomplete) return true
        if (hintSet.any { it in otherHints } || autocomplete.any { it in otherHints }) return false
        val type = html["type"]?.lowercase()
        if (type in nonText) return false
        val text = (texts + listOfNotNull(
            html["name"], html["id"], html["placeholder"], html["aria-label"], html["label"],
        )).joinToString(" ").lowercase()
        if (otpWord.containsMatchIn(text) || strong.any { text.contains(it) }) return true
        if (type == "password") return false
        val code = text.contains("code") || text.contains("código") || text.contains("codigo")
        return code && codeContext.any { text.contains(it) } && otherCodes.none { text.contains(it) }
    }
}
