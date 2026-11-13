package local.screenlink.android

import java.io.ByteArrayOutputStream

/** Minimal fragmented-MP4 writer for one H.264 video track (same layout as the iOS app's FMP4.h). */
object Mp4 {
    const val TIMESCALE = 1_000_000

    private class Writer {
        val out = ByteArrayOutputStream()
        private val patched = HashMap<Int, Int>()
        fun bytes(b: ByteArray) = out.write(b)
        fun ascii(s: String) = out.write(s.toByteArray(Charsets.US_ASCII))
        fun u8(v: Int) = out.write(v and 0xff)
        fun u16(v: Int) { u8(v ushr 8); u8(v) }
        fun u32(v: Long) { u16((v ushr 16).toInt()); u16(v.toInt()) }
        fun u32(v: Int) = u32(v.toLong() and 0xffffffffL)
        fun u64(v: Long) { u32(v ushr 32); u32(v and 0xffffffffL) }
        fun zero(n: Int) = repeat(n) { u8(0) }
        val size get() = out.size()
        fun box(name: String): Int { val at = size; u32(0); ascii(name); return at }
        fun end(at: Int) { patched[at] = size - at }
        fun patch(at: Int, v: Int) { patched[at] = v }
        fun matrix() = longArrayOf(0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000).forEach { u32(it) }
        fun result(): ByteArray {
            val a = out.toByteArray()
            for ((at, v) in patched) {
                a[at] = (v ushr 24).toByte(); a[at + 1] = (v ushr 16).toByte()
                a[at + 2] = (v ushr 8).toByte(); a[at + 3] = v.toByte()
            }
            return a
        }
    }

    fun codecString(sps: ByteArray): String =
        "avc1." + (1..3).joinToString("") { "%02x".format(sps[it].toInt() and 0xff) }

    fun init(sps: ByteArray, pps: ByteArray, width: Int, height: Int): ByteArray {
        require(sps.size in 4..65535 && pps.size in 1..65535 && width in 1..65535 && height in 1..65535)
        val w = Writer()
        var b = w.box("ftyp"); w.ascii("iso6"); w.u32(1); w.ascii("iso6isommp41avc1"); w.end(b)
        val moov = w.box("moov")
        b = w.box("mvhd"); w.u32(0); w.zero(8); w.u32(TIMESCALE); w.u32(0); w.u32(0x10000); w.u16(0x100); w.zero(10); w.matrix(); w.zero(24); w.u32(2); w.end(b)
        val trak = w.box("trak")
        b = w.box("tkhd"); w.u32(7); w.zero(8); w.u32(1); w.zero(16); w.zero(8); w.matrix(); w.u32(width.toLong() shl 16); w.u32(height.toLong() shl 16); w.end(b)
        val mdia = w.box("mdia")
        b = w.box("mdhd"); w.u32(0); w.zero(8); w.u32(TIMESCALE); w.u32(0); w.u16(0x55c4); w.u16(0); w.end(b)
        b = w.box("hdlr"); w.zero(8); w.ascii("vide"); w.zero(12); w.ascii("ScreenLink"); w.u8(0); w.end(b)
        val minf = w.box("minf")
        b = w.box("vmhd"); w.u32(1); w.zero(8); w.end(b)
        val dinf = w.box("dinf"); b = w.box("dref"); w.u32(0); w.u32(1); val url = w.box("url "); w.u32(1); w.end(url); w.end(b); w.end(dinf)
        val stbl = w.box("stbl"); val stsd = w.box("stsd"); w.u32(0); w.u32(1)
        val avc = w.box("avc1"); w.zero(6); w.u16(1); w.zero(16); w.u16(width); w.u16(height)
        w.u32(0x480000); w.u32(0x480000); w.u32(0); w.u16(1); w.zero(32); w.u16(24); w.u16(0xffff)
        b = w.box("avcC"); w.u8(1); w.u8(sps[1].toInt()); w.u8(sps[2].toInt()); w.u8(sps[3].toInt()); w.u8(0xff); w.u8(0xe1)
        w.u16(sps.size); w.bytes(sps); w.u8(1); w.u16(pps.size); w.bytes(pps); w.end(b)
        w.end(avc); w.end(stsd)
        for ((i, name) in listOf("stts", "stsc", "stsz", "stco").withIndex()) { b = w.box(name); w.u32(0); w.u32(0); if (i == 2) w.u32(0); w.end(b) }
        w.end(stbl); w.end(minf); w.end(mdia); w.end(trak)
        val mvex = w.box("mvex"); b = w.box("trex"); w.u32(0); w.u32(1); w.u32(1); w.zero(12); w.end(b); w.end(mvex)
        w.end(moov)
        return w.result()
    }

    /** One moof+mdat holding a single AVCC (length-prefixed) access unit. */
    fun fragment(avcc: ByteArray, sequence: Int, time: Long, duration: Int, key: Boolean): ByteArray {
        require(avcc.isNotEmpty() && duration > 0)
        val w = Writer()
        val moof = w.box("moof")
        var b = w.box("mfhd"); w.u32(0); w.u32(sequence); w.end(b)
        val traf = w.box("traf")
        b = w.box("tfhd"); w.u32(0x020000); w.u32(1); w.end(b)
        b = w.box("tfdt"); w.u32(0x01000000); w.u64(time); w.end(b)
        b = w.box("trun"); w.u32(0x701); w.u32(1); val offset = w.size; w.u32(0); w.u32(duration); w.u32(avcc.size)
        w.u32(if (key) 0x02000000 else 0x01010000); w.end(b)
        w.end(traf); w.end(moof)
        w.patch(offset, w.size + 8)
        b = w.box("mdat"); w.bytes(avcc); w.end(b)
        return w.result()
    }
}

/** Annex B (start-code) helpers. */
object AnnexB {
    /** Returns (offset, length) of each NAL unit payload, without start codes. */
    fun nals(data: ByteArray, from: Int = 0, to: Int = data.size): List<IntArray> {
        val starts = ArrayList<IntArray>() // [startCodeIndex, payloadIndex]
        var i = from
        while (i + 2 < to) {
            if (data[i].toInt() == 0 && data[i + 1].toInt() == 0) {
                if (data[i + 2].toInt() == 1) { starts.add(intArrayOf(i, i + 3)); i += 3; continue }
                if (i + 3 < to && data[i + 2].toInt() == 0 && data[i + 3].toInt() == 1) { starts.add(intArrayOf(i, i + 4)); i += 4; continue }
            }
            i++
        }
        val result = ArrayList<IntArray>()
        for ((n, s) in starts.withIndex()) {
            var end = if (n + 1 < starts.size) starts[n + 1][0] else to
            while (end > s[1] && data[end - 1].toInt() == 0 && n + 1 < starts.size) end-- // trailing zeros
            if (end > s[1]) result.add(intArrayOf(s[1], end - s[1]))
        }
        return result
    }

    fun type(data: ByteArray, nal: IntArray) = data[nal[0]].toInt() and 0x1f

    class Sample(val avcc: ByteArray, val key: Boolean, val sps: ByteArray?, val pps: ByteArray?)

    /** Converts an Annex B access unit to AVCC, removing parameter sets and delimiters. */
    fun toSample(data: ByteArray): Sample? {
        val out = ByteArrayOutputStream(data.size + 16)
        var key = false; var sps: ByteArray? = null; var pps: ByteArray? = null
        for (nal in nals(data)) {
            when (type(data, nal)) {
                7 -> sps = data.copyOfRange(nal[0], nal[0] + nal[1])
                8 -> pps = data.copyOfRange(nal[0], nal[0] + nal[1])
                9 -> {}
                else -> {
                    if (type(data, nal) == 5) key = true
                    val n = nal[1]
                    out.write(n ushr 24); out.write(n ushr 16); out.write(n ushr 8); out.write(n)
                    out.write(data, nal[0], n)
                }
            }
        }
        if (out.size() == 0) return null
        return Sample(out.toByteArray(), key, sps, pps)
    }
}
