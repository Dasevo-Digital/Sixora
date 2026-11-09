package de.status403.sixora

import org.junit.Assert.assertEquals
import org.junit.Test

class PasskeyIndexTest {
    /** The same value as in sixora_core's passkey_test.dart. */
    @Test
    fun matchesTheHashOfTheDartSide() {
        assertEquals(
            "EGO7tFHYWdc03T+H6Fh0uqZBiNSyvfRW+QBRUZfTPAc=",
            PasskeyIndex.siteHash("salz", "example.com"),
        )
    }
}
