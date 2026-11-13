package local.screenlink.android

import java.io.BufferedInputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.URLDecoder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** What the web server needs from the capture side. */
interface StreamSource {
    val h264: H264Hub
    val jpeg: JpegHub
    val mode: String            // "h264" or "jpeg"
    fun statusJson(): String
    fun requestMode(mode: String)
}

/** Tiny HTTP/1.1 server for the browser viewer. GET only; keep-alive supported. */
class WebServer(
    private val source: StreamSource,
    private val token: String,
    private val shortLink: () -> Boolean,
    private val viewerHtml: ByteArray,
    private val log: (String) -> Unit,
) {
    private var server: ServerSocket? = null
    private val pool = Executors.newCachedThreadPool { r -> Thread(r, "web").apply { isDaemon = true } }
    private val connections = AtomicInteger()
    private val streams = AtomicInteger()
    @Volatile var port = 0; private set

    fun start(preferred: Int = 8080): Int {
        var lastError: Exception? = null
        for (p in preferred until preferred + 10) {
            try {
                val s = ServerSocket()
                s.reuseAddress = true
                s.bind(InetSocketAddress(p), 32)
                server = s; port = p
                Thread({ acceptLoop(s) }, "web-accept").apply { isDaemon = true }.start()
                return p
            } catch (e: Exception) { lastError = e }
        }
        throw lastError ?: IllegalStateException("No port")
    }

    fun stop() {
        try { server?.close() } catch (_: Exception) {}
        server = null
        pool.shutdownNow()
    }

    private fun acceptLoop(s: ServerSocket) {
        while (!s.isClosed) {
            val client = try { s.accept() } catch (_: Exception) { break }
            if (connections.incrementAndGet() > 24) {
                connections.decrementAndGet(); try { client.close() } catch (_: Exception) {}; continue
            }
            pool.execute {
                try { serve(client) } catch (_: Exception) {} finally {
                    connections.decrementAndGet(); try { client.close() } catch (_: Exception) {}
                }
            }
        }
    }

    private class Request(val path: String, val query: Map<String, String>)

    private fun readLine(input: InputStream): String? {
        val sb = StringBuilder()
        while (true) {
            val c = input.read()
            if (c < 0) return if (sb.isEmpty()) null else sb.toString()
            if (c == '\n'.code) return sb.toString().trimEnd('\r')
            if (sb.length > 8192) throw SocketException("Line too long")
            sb.append(c.toChar())
        }
    }

    private fun readRequest(input: InputStream): Request? {
        val line = readLine(input) ?: return null
        while (true) { val h = readLine(input) ?: return null; if (h.isEmpty()) break }
        val parts = line.split(' ')
        if (parts.size < 2) return null
        val target = parts[1]
        val q = target.indexOf('?')
        val path = if (q >= 0) target.substring(0, q) else target
        val query = HashMap<String, String>()
        if (q >= 0) for (pair in target.substring(q + 1).split('&')) {
            if (pair.isEmpty()) continue
            val eq = pair.indexOf('=')
            val k = URLDecoder.decode(if (eq >= 0) pair.substring(0, eq) else pair, "UTF-8")
            val v = if (eq >= 0) URLDecoder.decode(pair.substring(eq + 1), "UTF-8") else ""
            query[k] = v
        }
        return Request(path, query)
    }

    private fun send(out: OutputStream, status: String, type: String, body: ByteArray, extra: String = "") {
        val head = "HTTP/1.1 $status\r\nContent-Type: $type\r\nContent-Length: ${body.size}\r\n" +
            "Cache-Control: no-store\r\nAccess-Control-Expose-Headers: X-Stream-Epoch, X-Last-ID, X-Frame-ID\r\n" +
            "Connection: keep-alive\r\n$extra\r\n"
        out.write(head.toByteArray(Charsets.US_ASCII)); out.write(body); out.flush()
    }

    private fun text(out: OutputStream, status: String, message: String) =
        send(out, status, "text/plain; charset=utf-8", message.toByteArray())

    private fun serve(socket: Socket) {
        socket.tcpNoDelay = true
        socket.soTimeout = 30_000
        val input = BufferedInputStream(socket.getInputStream())
        val out = socket.getOutputStream().buffered(64 * 1024)
        while (true) {
            val req = readRequest(input) ?: return
            if (!handle(req, out, socket)) return
        }
    }

    /** Returns false when the connection must close (streams). */
    private fun handle(req: Request, out: OutputStream, socket: Socket): Boolean {
        if (req.path == "/" || req.path == "/index.html") {
            if (shortLink()) {
                send(out, "302 Found", "text/plain", ByteArray(0), "Location: /view?token=$token\r\n")
            } else {
                text(out, "403 Forbidden", "Open the full viewer link shown in the ScreenLink app (it includes ?token=…).")
            }
            return true
        }
        if (req.path == "/favicon.ico") { send(out, "404 Not Found", "text/plain", ByteArray(0)); return true }
        if (req.query["token"] != token) {
            text(out, "403 Forbidden", "This viewer link is not valid. Copy the current link from the ScreenLink app.")
            return true
        }
        when (req.path) {
            "/view" -> send(out, "200 OK", "text/html; charset=utf-8", viewerHtml)
            "/status.json" -> send(out, "200 OK", "application/json", source.statusJson().toByteArray())
            "/mode" -> {
                val m = req.query["set"]
                if (m == "h264" || m == "jpeg") { source.requestMode(m); log("Viewer switched mode to $m") }
                send(out, "200 OK", "application/json", source.statusJson().toByteArray())
            }
            "/h264/info" -> {
                val i = source.h264.info()
                val json = "{\"epoch\":\"${i["epoch"]}\",\"ready\":${i["ready"] == true && source.mode == "h264"}," +
                    "\"codec\":\"${i["codec"]}\",\"sequence\":${i["sequence"]}}"
                send(out, "200 OK", "application/json", json.toByteArray())
            }
            "/h264/init.mp4" -> {
                val (epoch, data) = source.h264.initSegment()
                if (data == null) text(out, "503 Service Unavailable", "Not ready")
                else send(out, "200 OK", "video/mp4", data, "X-Stream-Epoch: $epoch\r\n")
            }
            "/h264/segments" -> {
                val after = req.query["after"]?.toLongOrNull() ?: 0L
                val r = source.h264.readAfter(after, req.query["epoch"] ?: "", 2_000)
                when {
                    r.reset -> text(out, "409 Conflict", "Stream restarted")
                    r.data == null -> send(out, "204 No Content", "video/mp4", ByteArray(0), "X-Stream-Epoch: ${r.epoch}\r\nX-Last-ID: ${r.lastId}\r\n")
                    else -> send(out, "200 OK", "video/mp4", r.data, "X-Stream-Epoch: ${r.epoch}\r\nX-Last-ID: ${r.lastId}\r\n")
                }
            }
            "/frame.jpg" -> {
                val after = req.query["after"]?.toLongOrNull() ?: 0L
                val f = source.jpeg.next(after, 2_000)
                if (f == null) send(out, "204 No Content", "image/jpeg", ByteArray(0))
                else send(out, "200 OK", "image/jpeg", f.second, "X-Frame-ID: ${f.first}\r\n")
            }
            "/stream.mjpg" -> { mjpeg(out, socket); return false }
            else -> text(out, "404 Not Found", "Not found")
        }
        return true
    }

    private fun mjpeg(out: OutputStream, socket: Socket) {
        if (streams.incrementAndGet() > 3) {
            streams.decrementAndGet(); text(out, "503 Service Unavailable", "Too many viewers"); return
        }
        try {
            socket.soTimeout = 0
            out.write(("HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=screenlinkframe\r\n" +
                "Cache-Control: no-store\r\nConnection: close\r\n\r\n").toByteArray())
            out.flush()
            var last = 0L
            while (!socket.isClosed) {
                // Repeat the current frame when the screen is idle, so a dead viewer is noticed.
                val f = source.jpeg.next(last, 5_000) ?: source.jpeg.next(0, 0) ?: continue
                last = f.first
                out.write("--screenlinkframe\r\nContent-Type: image/jpeg\r\nContent-Length: ${f.second.size}\r\n\r\n".toByteArray())
                out.write(f.second); out.write("\r\n".toByteArray()); out.flush()
            }
        } finally { streams.decrementAndGet() }
    }
}
