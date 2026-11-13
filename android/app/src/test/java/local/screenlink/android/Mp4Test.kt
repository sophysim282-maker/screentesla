package local.screenlink.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Mp4Test {
    private val sps = byteArrayOf(0x67, 0x42.toByte(), 0xc0.toByte(), 0x1e, 0x89.toByte())
    private val pps = byteArrayOf(0x68, 0xcb.toByte(), 0x83.toByte(), 0xcb.toByte())

    private fun fourcc(data: ByteArray, at: Int) = String(data, at + 4, 4, Charsets.US_ASCII)

    @Test fun initSegmentHasExpectedBoxes() {
        val init = Mp4.init(sps, pps, 640, 360)
        assertTrue(init.size > 500)
        assertEquals("ftyp", fourcc(init, 0))
        // moov follows ftyp.
        val ftypLen = ((init[0].toInt() and 0xff) shl 24) or ((init[1].toInt() and 0xff) shl 16) or
            ((init[2].toInt() and 0xff) shl 8) or (init[3].toInt() and 0xff)
        assertEquals("moov", fourcc(init, ftypLen))
    }

    @Test fun codecStringMatchesSps() {
        assertEquals("avc1.42c01e", Mp4.codecString(sps))
    }

    @Test fun fragmentCarriesPayload() {
        val avcc = byteArrayOf(0, 0, 0, 2, 0x65, 0x88.toByte())
        val frag = Mp4.fragment(avcc, 1, 0, 16_667, true)
        assertEquals("moof", fourcc(frag, 0))
        assertTrue(frag.size > avcc.size)
    }

    @Test(expected = IllegalArgumentException::class)
    fun fragmentRejectsZeroDuration() {
        Mp4.fragment(byteArrayOf(1, 2, 3), 1, 0, 0, true)
    }

    @Test fun annexBSplitsNalsAndStripsParameterSets() {
        // start code | SPS(7) | start code | PPS(8) | start code | IDR(5) payload
        val stream = byteArrayOf(
            0, 0, 0, 1, 0x67, 0x42, 0x01,
            0, 0, 1, 0x68, 0xcb.toByte(),
            0, 0, 0, 1, 0x65, 0x11, 0x22, 0x33
        )
        val sample = AnnexB.toSample(stream)
        assertNotNull(sample)
        assertTrue(sample!!.key)
        assertNotNull(sample.sps)
        assertNotNull(sample.pps)
        // AVCC: 4-byte length prefix + the 4-byte IDR NAL.
        assertEquals(8, sample.avcc.size)
        assertEquals(4, sample.avcc[3].toInt())
        assertEquals(0x65, sample.avcc[4].toInt() and 0xff)
    }

    @Test fun annexBReturnsNullWhenOnlyParameterSets() {
        val stream = byteArrayOf(0, 0, 0, 1, 0x67, 0x42, 0x01, 0, 0, 0, 1, 0x68, 0xcb.toByte())
        assertNull(AnnexB.toSample(stream))
    }
}
