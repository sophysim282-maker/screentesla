package local.screenlink.android

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.net.Inet4Address
import java.net.NetworkInterface

class MainActivity : Activity() {
    private val requestCapture = 10
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var status: TextView
    private lateinit var links: LinearLayout
    private lateinit var logView: TextView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var modeGroup: RadioGroup
    private lateinit var profileGroup: RadioGroup
    private var lastLinks = ""
    private val prefs by lazy { getSharedPreferences("screenlink", Context.MODE_PRIVATE) }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.parseColor("#10141c")
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(18), dp(18), dp(24))
            setBackgroundColor(Color.parseColor("#10141c"))
        }
        fun label(text: String, size: Float = 15f, bold: Boolean = false, color: String = "#e8edf5") = TextView(this).apply {
            this.text = text; textSize = size; setTextColor(Color.parseColor(color))
            if (bold) typeface = Typeface.DEFAULT_BOLD
            setPadding(0, dp(6), 0, dp(6))
        }
        root.addView(label("ScreenLink for Android", 24f, true))
        root.addView(label("Show your phone screen in the Tesla browser over your phone's hotspot.", 14f, color = "#9fb0c8"))

        status = label("", 16f, true, "#7fd1ff")
        root.addView(status)

        startButton = Button(this).apply { text = "Start sharing"; setOnClickListener { askForCapture() } }
        stopButton = Button(this).apply {
            text = "Stop sharing"
            setOnClickListener { startService(Intent(this@MainActivity, CaptureService::class.java).setAction(CaptureService.ACTION_STOP)) }
        }
        root.addView(LinearLayout(this).apply {
            addView(startButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(stopButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        })

        root.addView(label("Viewer links (open one in the Tesla browser)", 15f, true))
        links = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(links)

        root.addView(label("Video type", 15f, true))
        modeGroup = RadioGroup(this)
        val modes = listOf("h264" to "H.264 video — sharp and smooth (best when parked)",
            "jpeg" to "JPEG pictures — use if the video stops while driving")
        for ((i, m) in modes.withIndex()) modeGroup.addView(radio(m.second, 100 + i))
        modeGroup.check(if (prefs.getString("mode", "h264") == "jpeg") 101 else 100)
        modeGroup.setOnCheckedChangeListener { _, id ->
            val mode = if (id == 101) "jpeg" else "h264"
            prefs.edit().putString("mode", mode).apply()
            if (CaptureService.running) startService(Intent(this, CaptureService::class.java)
                .setAction(CaptureService.ACTION_MODE).putExtra(CaptureService.EXTRA_MODE, mode))
        }
        root.addView(modeGroup)

        root.addView(label("Quality", 15f, true))
        profileGroup = RadioGroup(this)
        for ((i, p) in Profile.entries.withIndex()) profileGroup.addView(radio(p.label, 200 + i))
        val saved = Profile.entries.indexOfFirst { it.name == prefs.getString("profile", "HD") }.coerceAtLeast(0)
        profileGroup.check(200 + saved)
        profileGroup.setOnCheckedChangeListener { _, id ->
            val p = Profile.entries[id - 200]
            prefs.edit().putString("profile", p.name).apply()
            if (CaptureService.running) startService(Intent(this, CaptureService::class.java)
                .setAction(CaptureService.ACTION_PROFILE).putExtra(CaptureService.EXTRA_PROFILE, p.name))
        }
        root.addView(profileGroup)

        root.addView(CheckBox(this).apply {
            text = "Allow short link without token (anyone on your hotspot can watch)"
            setTextColor(Color.parseColor("#e8edf5"))
            isChecked = CaptureService.shortLinkEnabled(this@MainActivity)
            setOnCheckedChangeListener { _, on -> prefs.edit().putBoolean("shortLink", on).apply(); lastLinks = ""; refresh() }
        })

        root.addView(label("How to use", 15f, true))
        root.addView(label(
            "1. Turn on Hotspot on this phone.\n" +
            "2. In the Tesla: Wi-Fi → join this phone's hotspot.\n" +
            "3. Tap Start sharing and allow \"entire screen\".\n" +
            "4. Open the Tesla browser and type the short link (or full link) shown above.\n" +
            "5. Keep this phone unlocked. Sound plays through the car's Bluetooth as usual.", 14f, color = "#c4cfdf"))

        root.addView(label("Log", 15f, true))
        logView = label("", 12f, color = "#9fb0c8").apply { typeface = Typeface.MONOSPACE; inputType = InputType.TYPE_NULL }
        root.addView(logView)

        setContentView(ScrollView(this).apply { setBackgroundColor(Color.parseColor("#10141c")); addView(root) })

        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    private fun radio(text: String, id: Int) = RadioButton(this).apply {
        this.text = text; this.id = id; setTextColor(Color.parseColor("#e8edf5"))
    }

    private val tick = object : Runnable {
        override fun run() { refresh(); handler.postDelayed(this, 1000) }
    }

    override fun onResume() { super.onResume(); handler.post(tick) }
    override fun onPause() { super.onPause(); handler.removeCallbacks(tick) }

    private fun askForCapture() {
        val manager = getSystemService(MediaProjectionManager::class.java)
        startActivityForResult(manager.createScreenCaptureIntent(), requestCapture)
    }

    @Deprecated("Activity result API without AndroidX")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestCapture) return
        if (resultCode != RESULT_OK || data == null) {
            Toast.makeText(this, "Screen sharing was not allowed", Toast.LENGTH_SHORT).show(); return
        }
        val intent = Intent(this, CaptureService::class.java).setAction(CaptureService.ACTION_START)
            .putExtra(CaptureService.EXTRA_RESULT_CODE, resultCode)
            .putExtra(CaptureService.EXTRA_DATA, data)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }

    private fun addresses(): List<Pair<String, String>> {
        val result = ArrayList<Pair<String, String>>()
        try {
            for (ni in NetworkInterface.getNetworkInterfaces()) {
                if (!ni.isUp || ni.isLoopback) continue
                for (a in ni.inetAddresses) if (a is Inet4Address && !a.isLoopbackAddress) result.add(ni.name to a.hostAddress!!)
            }
        } catch (_: Exception) {}
        // Hotspot-looking interfaces first (ap0, swlan0, wlan1, softap…), mobile data last.
        fun rank(name: String) = when {
            name.startsWith("ap") || name.startsWith("swlan") || name.startsWith("softap") || name == "wlan1" || name == "wlan2" -> 0
            name.startsWith("wlan") || name.startsWith("rndis") || name.startsWith("usb") || name.startsWith("eth") -> 1
            else -> 2
        }
        val local = result.filter { rank(it.first) < 2 }
        return (if (local.isNotEmpty()) local else result).sortedBy { rank(it.first) }
    }

    private fun refresh() {
        val running = CaptureService.running
        val port = CaptureService.port
        startButton.isEnabled = !running
        stopButton.isEnabled = running
        status.text = if (running) "● Sharing — open a link below in the Tesla browser" else "Not sharing"
        status.setTextColor(Color.parseColor(if (running) "#6be39b" else "#9fb0c8"))
        logView.text = CaptureService.logText()

        val token = CaptureService.token(this)
        val list = if (running && port > 0) addresses() else emptyList()
        val key = list.joinToString() + port + CaptureService.shortLinkEnabled(this)
        if (key == lastLinks) return
        lastLinks = key
        links.removeAllViews()
        if (!running) { links.addView(linkLabel("Start sharing to see the links.", null)); return }
        if (list.isEmpty()) { links.addView(linkLabel("No network found. Turn on the hotspot.", null)); return }
        for ((name, ip) in list) {
            val short = "http://$ip:$port/"
            val full = "http://$ip:$port/view?token=$token"
            links.addView(linkLabel("$name", null).apply { textSize = 12f; setTextColor(Color.parseColor("#9fb0c8")) })
            if (CaptureService.shortLinkEnabled(this)) links.addView(linkLabel(short, short).apply { textSize = 20f })
            links.addView(linkLabel(full, full))
        }
    }

    private fun linkLabel(text: String, copy: String?) = TextView(this).apply {
        this.text = text
        textSize = 15f
        setTextColor(Color.parseColor(if (copy != null) "#ffffff" else "#9fb0c8"))
        setPadding(dp(10), dp(8), dp(10), dp(8))
        if (copy != null) {
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply { setColor(Color.parseColor("#1d2a3c")); cornerRadius = dp(8).toFloat() }
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(4) }
            setOnClickListener {
                getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("ScreenLink", copy))
                Toast.makeText(this@MainActivity, "Link copied", Toast.LENGTH_SHORT).show()
            }
        }
        gravity = Gravity.START
    }
}
