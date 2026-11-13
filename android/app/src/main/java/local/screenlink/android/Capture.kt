package local.screenlink.android

import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.view.Surface
import java.io.ByteArrayOutputStream

/** Quality presets. Sizes are the longest edge of the captured image. */
enum class Profile(val label: String, val longEdge: Int, val bitrate: Int, val fps: Int, val jpegQuality: Int, val jpegFps: Int) {
    SAVER("Saver (720p)", 1280, 3_000_000, 30, 55, 12),
    HD("HD (1080p)", 1920, 6_000_000, 30, 60, 15),
    SMOOTH("Smooth (1080p 60)", 1920, 10_000_000, 60, 60, 20);
}

/**
 * One MediaProjection VirtualDisplay whose output surface is switched between an H.264
 * encoder (best quality) and an ImageReader producing JPEGs (works where <video> is blocked).
 */
class Capture(
    private val projection: MediaProjection,
    private val h264: H264Hub,
    private val jpeg: JpegHub,
    private val log: (String) -> Unit,
) {
    private val thread = HandlerThread("capture").apply { start() }
    private val handler = Handler(thread.looper)
    private var display: VirtualDisplay? = null
    private var encoder: MediaCodec? = null
    private var encoderSurface: Surface? = null
    private var reader: ImageReader? = null
    private var bitmap: Bitmap? = null
    private var lastJpegAt = 0L
    private var lastKeyRequest = 0L
    @Volatile var mode = "h264"; private set
    @Volatile var profile = Profile.HD; private set
    @Volatile var width = 0; private set
    @Volatile var height = 0; private set
    private var screenW = 0
    private var screenH = 0
    private var dpi = 160

    init {
        h264.keyframeNeeded = { requestKeyframe() }
    }

    fun start(screenWidth: Int, screenHeight: Int, densityDpi: Int, mode: String, profile: Profile) = handler.post {
        screenW = screenWidth; screenH = screenHeight; dpi = densityDpi; this.mode = mode; this.profile = profile
        computeSize()
        val surface = createConsumer()
        display = projection.createVirtualDisplay("ScreenLink", width, height, dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, surface, null, handler)
        log("Capturing ${width}×$height in ${label()}")
    }

    fun setMode(newMode: String) = handler.post {
        if (newMode == mode || display == null) return@post
        mode = newMode; reconfigure("Switched to ${label()}")
    }

    fun setProfile(p: Profile) = handler.post {
        if (p == profile || display == null) return@post
        profile = p; computeSize(); reconfigure("Quality ${p.label}: ${width}×$height")
    }

    fun screenChanged(screenWidth: Int, screenHeight: Int, densityDpi: Int) = handler.post {
        if (screenWidth == screenW && screenHeight == screenH) return@post
        screenW = screenWidth; screenH = screenHeight; dpi = densityDpi
        if (display == null) return@post
        computeSize(); reconfigure("Rotated: ${width}×$height")
    }

    fun stop() {
        handler.post {
            releaseConsumers()
            display?.release(); display = null
        }
        thread.quitSafely()
    }

    private fun label() = if (mode == "h264") "H.264 mode" else "JPEG mode"

    private fun reconfigure(message: String) {
        val old = display ?: return
        old.surface = null
        releaseConsumers()
        val surface = createConsumer()
        old.resize(width, height, dpi)
        old.surface = surface
        log(message)
    }

    private fun computeSize() {
        val longEdge = maxOf(screenW, screenH).coerceAtLeast(1)
        val scale = minOf(1.0, profile.longEdge.toDouble() / longEdge)
        // Multiples of 16 keep every hardware encoder happy.
        width = ((screenW * scale).toInt() / 16 * 16).coerceAtLeast(16)
        height = ((screenH * scale).toInt() / 16 * 16).coerceAtLeast(16)
    }

    private fun createConsumer(): Surface =
        if (mode == "h264") createEncoder() else createReader()

    private fun releaseConsumers() {
        encoder?.let { try { it.stop() } catch (_: Exception) {}; try { it.release() } catch (_: Exception) {} }
        encoder = null
        encoderSurface?.release(); encoderSurface = null
        reader?.setOnImageAvailableListener(null, null)
        reader?.close(); reader = null
        bitmap?.recycle(); bitmap = null
        h264.reset(); jpeg.clear()
    }

    private fun createEncoder(): Surface {
        h264.reset()
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        fun format(baseline: Boolean) = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, profile.bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, profile.fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
            // Keep sending frames when the screen is still, so new viewers and stalls recover quickly.
            setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 100_000L)
            if (baseline) {
                // Baseline has no B-frames, so decode order equals display order.
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline)
                setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel41)
            }
            if (Build.VERSION.SDK_INT >= 30) setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
            if (Build.VERSION.SDK_INT >= 29) setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            setInteger(MediaFormat.KEY_PRIORITY, 0)
        }
        try {
            codec.configure(format(true), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: Exception) {
            log("Baseline profile not accepted (${e.javaClass.simpleName}); using encoder default")
            codec.reset()
            codec.configure(format(false), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
        val w = width; val h = height
        codec.setCallback(object : MediaCodec.Callback() {
            override fun onInputBufferAvailable(c: MediaCodec, index: Int) {}
            override fun onOutputBufferAvailable(c: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
                if (c !== encoder) return
                try {
                    val buffer = c.getOutputBuffer(index)
                    if (buffer != null && info.size > 0) {
                        val bytes = ByteArray(info.size)
                        buffer.position(info.offset); buffer.get(bytes, 0, info.size)
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) h264.configure(bytes, w, h)
                        else h264.frame(bytes, info.presentationTimeUs)
                    }
                    c.releaseOutputBuffer(index, false)
                } catch (e: Exception) {
                    log("Encoder output error: ${e.message}")
                }
            }
            override fun onError(c: MediaCodec, e: MediaCodec.CodecException) { log("Encoder error: ${e.diagnosticInfo}") }
            override fun onOutputFormatChanged(c: MediaCodec, format: MediaFormat) {
                // Some encoders deliver SPS/PPS only here (csd-0 / csd-1).
                val sps = format.getByteBuffer("csd-0"); val pps = format.getByteBuffer("csd-1")
                if (sps != null && pps != null) {
                    val out = ByteArrayOutputStream()
                    for (b in listOf(sps, pps)) { val a = ByteArray(b.remaining()); b.duplicate().get(a); out.write(a) }
                    h264.configure(out.toByteArray(), w, h)
                }
            }
        }, handler)
        val surface = codec.createInputSurface()
        encoder = codec; encoderSurface = surface
        codec.start()
        return surface
    }

    private fun requestKeyframe() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastKeyRequest < 500) return
        lastKeyRequest = now
        handler.post {
            try { encoder?.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) }) } catch (_: Exception) {}
        }
    }

    private fun createReader(): Surface {
        jpeg.clear()
        val r = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        r.setOnImageAvailableListener({ source ->
            val image = try { source.acquireLatestImage() } catch (_: Exception) { null } ?: return@setOnImageAvailableListener
            try {
                val now = SystemClock.elapsedRealtime()
                if (now - lastJpegAt < 1000L / profile.jpegFps) return@setOnImageAvailableListener
                lastJpegAt = now
                val plane = image.planes[0]
                val rowPixels = plane.rowStride / plane.pixelStride
                var bmp = bitmap
                if (bmp == null || bmp.width != rowPixels || bmp.height != image.height) {
                    bmp?.recycle()
                    bmp = Bitmap.createBitmap(rowPixels, image.height, Bitmap.Config.ARGB_8888); bitmap = bmp
                }
                plane.buffer.rewind()
                bmp.copyPixelsFromBuffer(plane.buffer)
                val out = ByteArrayOutputStream(256 * 1024)
                val visible = if (rowPixels == image.width) bmp else Bitmap.createBitmap(bmp, 0, 0, image.width, image.height)
                visible.compress(Bitmap.CompressFormat.JPEG, profile.jpegQuality, out)
                if (visible !== bmp) visible.recycle()
                jpeg.publish(out.toByteArray())
            } catch (e: Exception) {
                log("JPEG error: ${e.message}")
            } finally {
                image.close()
            }
        }, handler)
        reader = r
        return r.surface
    }
}
