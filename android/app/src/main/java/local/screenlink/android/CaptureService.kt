package local.screenlink.android

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.hardware.display.DisplayManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.DisplayMetrics
import android.view.Display
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Foreground service that owns the screen capture and the web server. */
class CaptureService : Service(), StreamSource {
    companion object {
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val ACTION_MODE = "mode"
        const val ACTION_PROFILE = "profile"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        const val EXTRA_MODE = "modeValue"
        const val EXTRA_PROFILE = "profileValue"
        private const val CHANNEL = "sharing"

        @Volatile var running = false; private set
        @Volatile var port = 0; private set
        @Volatile var instance: CaptureService? = null; private set
        private val logLines = ArrayDeque<String>()

        fun log(message: String) = synchronized(logLines) {
            logLines.addLast(SimpleDateFormat("HH:mm:ss", Locale.US).format(Date()) + "  " + message)
            while (logLines.size > 60) logLines.removeFirst()
        }
        fun logText(): String = synchronized(logLines) { logLines.reversed().joinToString("\n") }

        fun token(context: Context): String {
            val prefs = context.getSharedPreferences("screenlink", Context.MODE_PRIVATE)
            prefs.getString("token", null)?.let { return it }
            val alphabet = "abcdefghjkmnpqrstuvwxyz23456789"
            val random = SecureRandom()
            val t = (1..10).map { alphabet[random.nextInt(alphabet.length)] }.joinToString("")
            prefs.edit().putString("token", t).apply()
            return t
        }
        fun shortLinkEnabled(context: Context) =
            context.getSharedPreferences("screenlink", Context.MODE_PRIVATE).getBoolean("shortLink", true)
    }

    override val h264 = H264Hub()
    override val jpeg = JpegHub()
    override val mode: String get() = capture?.mode ?: "h264"
    private var projection: MediaProjection? = null
    private var capture: Capture? = null
    private var server: WebServer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> start(intent)
            ACTION_STOP -> stopSharing()
            ACTION_MODE -> intent.getStringExtra(EXTRA_MODE)?.let { requestMode(it) }
            ACTION_PROFILE -> intent.getStringExtra(EXTRA_PROFILE)?.let { name ->
                Profile.entries.firstOrNull { it.name == name }?.let { capture?.setProfile(it) }
            }
        }
        return START_NOT_STICKY
    }

    private fun start(intent: Intent) {
        if (running) return
        // Must be in the foreground with the mediaProjection type before getMediaProjection (Android 14+).
        val notification = notification()
        if (Build.VERSION.SDK_INT >= 29) startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        else startForeground(1, notification)

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        val data: Intent? = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
            else @Suppress("DEPRECATION") intent.getParcelableExtra(EXTRA_DATA)
        val manager = getSystemService(MediaProjectionManager::class.java)
        val p = try { if (data != null) manager.getMediaProjection(resultCode, data) else null } catch (e: Exception) {
            log("Screen capture refused: ${e.message}"); null
        }
        if (p == null) { log("Screen capture permission was not granted"); stopSelf(); return }
        projection = p
        p.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { log("Android stopped screen capture"); main.post { stopSharing() } }
        }, main)

        instance = this
        running = true
        val prefs = getSharedPreferences("screenlink", Context.MODE_PRIVATE)
        val startMode = intent.getStringExtra(EXTRA_MODE) ?: prefs.getString("mode", "h264") ?: "h264"
        val profile = Profile.entries.firstOrNull { it.name == (intent.getStringExtra(EXTRA_PROFILE) ?: prefs.getString("profile", "HD")) } ?: Profile.HD

        val html = assets.open("viewer.html").use { it.readBytes() }
        val web = WebServer(this, token(this), { shortLinkEnabled(this) }, html, ::log)
        try {
            port = web.start(8080); server = web; log("Web viewer listening on port $port")
        } catch (e: Exception) {
            log("Could not open web port: ${e.message}"); stopSharing(); return
        }

        val c = Capture(p, h264, jpeg, ::log)
        capture = c
        val (w, h, dpi) = screenSize()
        c.start(w, h, dpi, startMode, profile)

        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ScreenLink:sharing").apply { acquire(6 * 60 * 60 * 1000L) }
    }

    private fun screenSize(): Triple<Int, Int, Int> {
        val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION") display.getRealMetrics(metrics)
        return Triple(metrics.widthPixels, metrics.heightPixels, metrics.densityDpi)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Wait for the rotation to settle before reading the new size.
        main.postDelayed({ val (w, h, dpi) = screenSize(); capture?.screenChanged(w, h, dpi) }, 300)
    }

    override fun requestMode(mode: String) {
        if (mode != "h264" && mode != "jpeg") return
        getSharedPreferences("screenlink", Context.MODE_PRIVATE).edit().putString("mode", mode).apply()
        capture?.setMode(mode)
    }

    override fun statusJson(): String {
        val c = capture
        val now = System.currentTimeMillis()
        fun age(t: Long) = if (t == 0L) 999_999 else now - t
        return "{\"running\":$running,\"mode\":\"${mode}\",\"profile\":\"${c?.profile?.label ?: ""}\"," +
            "\"width\":${c?.width ?: 0},\"height\":${c?.height ?: 0}," +
            "\"h264Frames\":${h264.frames},\"jpegFrames\":${jpeg.frames}," +
            "\"compressedAgeMs\":${age(h264.lastFrameAt)},\"frameAgeMs\":${age(jpeg.lastFrameAt)}}"
    }

    private fun stopSharing() {
        if (running) log("Sharing stopped")
        running = false
        capture?.stop(); capture = null
        server?.stop(); server = null
        try { projection?.stop() } catch (_: Exception) {}
        projection = null
        wakeLock?.let { if (it.isHeld) it.release() }; wakeLock = null
        instance = null; port = 0
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (running) stopSharing()
        super.onDestroy()
    }

    private fun notification(): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Screen sharing", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, CaptureService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        return builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("ScreenLink is sharing your screen")
            .setContentText("Open the link in the Tesla browser")
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
    }
}
