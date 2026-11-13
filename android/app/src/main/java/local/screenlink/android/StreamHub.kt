package local.screenlink.android

import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Holds the current H.264 stream as fMP4 fragments, starting at the most recent keyframe,
 * so a new browser can begin decoding immediately. Each frame is held back until the next
 * one arrives so its real duration is known (no gaps for MediaSource).
 */
class H264Hub(private val maxBytes: Int = 12 * 1024 * 1024) {
    private class Unit(val id: Long, val data: ByteArray, val key: Boolean)
    class Read(val reset: Boolean, val epoch: String, val lastId: Long, val data: ByteArray?)

    private val lock = ReentrantLock()
    private val changed = lock.newCondition()
    private var epoch = UUID.randomUUID().toString()
    private var codec = ""
    private var init: ByteArray? = null
    private var sps: ByteArray? = null
    private var pps: ByteArray? = null
    private val units = ArrayDeque<Unit>()
    private var bytes = 0L
    private var sequence = 0L
    private var base = -1L
    private var pending: AnnexB.Sample? = null
    private var pendingTime = 0L
    private var lastDuration = 33_333
    @Volatile var frames = 0L; private set
    @Volatile var lastFrameAt = 0L; private set
    /** Called when history no longer starts with a keyframe (new viewers need one). */
    var keyframeNeeded: (() -> kotlin.Unit)? = null

    fun reset() = lock.withLock {
        epoch = UUID.randomUUID().toString(); codec = ""; init = null; sps = null; pps = null
        units.clear(); bytes = 0; sequence = 0; base = -1; pending = null; lastDuration = 33_333
        changed.signalAll()
    }

    /** Codec-config buffer (Annex B SPS + PPS) from the encoder. */
    fun configure(config: ByteArray, width: Int, height: Int) = lock.withLock {
        var s: ByteArray? = null; var p: ByteArray? = null
        for (nal in AnnexB.nals(config)) when (AnnexB.type(config, nal)) {
            7 -> s = config.copyOfRange(nal[0], nal[0] + nal[1])
            8 -> p = config.copyOfRange(nal[0], nal[0] + nal[1])
        }
        if (s == null || p == null || s.size < 4) return@withLock
        if (init != null && s.contentEquals(sps) && p.contentEquals(pps)) return@withLock
        val keepEpoch = init == null
        if (!keepEpoch) reset()
        sps = s; pps = p; codec = Mp4.codecString(s); init = Mp4.init(s, p, width, height)
        changed.signalAll()
    }

    fun frame(annexB: ByteArray, ptsUs: Long) {
        val sample = AnnexB.toSample(annexB) ?: return
        lock.withLock {
            if (init == null) return
            val previous = pending
            if (previous != null && ptsUs < pendingTime) { // clock went backwards: start over
                pending = null; units.clear(); bytes = 0; sequence = 0; base = -1
                epoch = UUID.randomUUID().toString()
                changed.signalAll()
            } else if (previous != null) {
                emit(previous, pendingTime, (ptsUs - pendingTime).coerceIn(1_000, 1_000_000).toInt())
            }
            if (base < 0) {
                if (!sample.key) { keyframeNeeded?.invoke(); return }
                base = ptsUs
            }
            pending = sample; pendingTime = ptsUs
            frames++; lastFrameAt = System.currentTimeMillis()
        }
    }

    private fun emit(sample: AnnexB.Sample, time: Long, duration: Int) {
        lastDuration = duration
        val id = ++sequence
        val data = Mp4.fragment(sample.avcc, id.toInt(), time - base, duration, sample.key)
        if (sample.key) { units.clear(); bytes = 0 }
        units.addLast(Unit(id, data, sample.key)); bytes += data.size
        while (bytes > maxBytes && units.size > 1) {
            bytes -= units.removeFirst().data.size
        }
        if (!units.first().key) keyframeNeeded?.invoke()
        changed.signalAll()
    }

    fun info(): Map<String, Any> = lock.withLock {
        mapOf("epoch" to epoch, "ready" to (init != null), "codec" to codec, "sequence" to sequence)
    }

    fun initSegment(): Pair<String, ByteArray?> = lock.withLock { epoch to init }

    /** Long-polls for fragments after [after]; `after == 0` means "start at the latest keyframe". */
    fun readAfter(after: Long, wantedEpoch: String, timeoutMs: Long): Read = lock.withLock {
        var remaining = timeoutMs * 1_000_000
        while (wantedEpoch == epoch && (units.isEmpty() || after >= sequence || (after == 0L && !units.first().key))) {
            if (remaining <= 0) break
            remaining = changed.awaitNanos(remaining)
        }
        if (wantedEpoch != epoch || after > sequence) return Read(true, epoch, 0, null)
        val first = units.firstOrNull()?.id ?: (sequence + 1)
        if (after != 0L && after + 1 < first) return Read(true, epoch, 0, null)
        if (units.isEmpty() || after >= sequence || (after == 0L && !units.first().key)) return Read(false, epoch, after, null)
        val out = ByteArrayOutputStream()
        var last = after
        for (u in units) if (u.id > after) { out.write(u.data); last = u.id }
        Read(false, epoch, last, out.toByteArray())
    }
}

/** Latest JPEG frame with long-poll support. */
class JpegHub {
    private val lock = ReentrantLock()
    private val changed = lock.newCondition()
    private var id = 0L
    private var jpeg: ByteArray? = null
    @Volatile var frames = 0L; private set
    @Volatile var lastFrameAt = 0L; private set

    fun publish(data: ByteArray) = lock.withLock {
        id++; jpeg = data; frames++; lastFrameAt = System.currentTimeMillis(); changed.signalAll()
    }

    fun clear() = lock.withLock { jpeg = null; changed.signalAll() }

    fun next(after: Long, timeoutMs: Long): Pair<Long, ByteArray>? = lock.withLock {
        var remaining = timeoutMs * 1_000_000
        while ((jpeg == null || id <= after) && remaining > 0) remaining = changed.awaitNanos(remaining)
        val frame = jpeg
        if (frame == null || id <= after) null else id to frame
    }
}
