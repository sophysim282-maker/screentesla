import UIKit
import WebKit
import AVKit

/// Build 111 (TEST): TikTok inside ScreenLink without screen recording.
/// TikTok's website runs in a web view in this app. The user logs in and swipes on the phone. The
/// playing video is handed to ScreenLink's own AirPlay receiver by iOS (the same hand-over YouTube
/// uses), and ScreenLink serves it to the car. Whether TikTok's videos survive that path is what
/// this test build finds out; every step writes a `TIKTOK TEST:` line to the log.

/// Headers the phone must send when it downloads a TikTok video for the car: TikTok only answers
/// requests that look like its own page (referer, the same browser name, the login cookies).
/// Only TikTok hosts get them; YouTube downloads are untouched.
@objc(SLMediaHeaders)
final class SLMediaHeaders: NSObject {
    private static let lock = NSLock()
    private static var cookie = ""
    private static var agent = ""

    static func update(cookie: String, agent: String) {
        lock.lock(); self.cookie = cookie; self.agent = agent; lock.unlock()
    }

    @objc(headersForHost:) static func headers(forHost host: String) -> [String: String] {
        let h = host.lowercased()
        guard ["tiktok", "byteoversea", "bytedance", "ibyteimg", "muscdn", "ttwstatic"].contains(where: { h.contains($0) }) else { return [:] }
        lock.lock(); defer { lock.unlock() }
        var result = ["Referer": "https://www.tiktok.com/"]
        if !agent.isEmpty { result["User-Agent"] = agent }
        if !cookie.isEmpty { result["Cookie"] = cookie }
        return result
    }
}

@objc(SLTikTokLauncher)
final class SLTikTokLauncher: NSObject {
    static var log: ((String) -> Void)?
    @objc static func setLog(_ block: @escaping (String) -> Void) { log = block }
    @objc static func controller() -> UIViewController {
        let made = TikTokViewController()
        made.modalPresentationStyle = .fullScreen
        return made
    }
}

final class TikTokViewController: UIViewController, WKNavigationDelegate {
    private static let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
    private var web: WKWebView!
    private let status = UILabel()
    private var timer: Timer?
    private var lastState = ""

    // Marks every video on the page as allowed for AirPlay and reports what kind of video is playing.
    private static let probe = """
    (function(){var vs=[].slice.call(document.querySelectorAll('video'));if(!vs.length)return 'none';
    var mid=innerHeight/2,best=null,bd=1e9;vs.forEach(function(v){v.setAttribute('x-webkit-airplay','allow');try{v.disableRemotePlayback=false;v.removeAttribute('disableremoteplayback');}catch(e){}
    var r=v.getBoundingClientRect();if(r.height<50)return;var d=Math.abs((r.top+r.bottom)/2-mid);if(d<bd){bd=d;best=v;}});
    if(!best)return 'none';var src=best.currentSrc||best.src||'';var kind=src.indexOf('blob:')===0?'blob':(src?'file':'nosrc');
    return kind+'|'+(best.paused?'paused':'playing')+'|'+(best.webkitCurrentPlaybackTargetIsWireless?'airplay':'local')+'|'+(best.webkitShowPlaybackTargetPicker?'picker':'nopicker');})()
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        web = WKWebView(frame: .zero, configuration: config)
        web.customUserAgent = Self.agent
        web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = true

        let close = UIButton(type: .system)
        close.setTitle("‹ ScreenLink", for: .normal)
        close.titleLabel?.font = .boldSystemFont(ofSize: 16)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        let title = UILabel()
        title.text = "TikTok (test)"
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 16)
        title.textAlignment = .center
        // The system AirPlay button: choose "ScreenLink VPN Phone" to send the playing video to the car.
        let route = AVRoutePickerView()
        route.tintColor = .white
        route.activeTintColor = .systemGreen
        route.prioritizesVideoDevices = true
        route.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let send = UIButton(type: .system)
        send.setTitle("Send to car", for: .normal)
        send.titleLabel?.font = .boldSystemFont(ofSize: 16)
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        let bar = UIStackView(arrangedSubviews: [close, title, send, route])
        bar.axis = .horizontal
        bar.spacing = 10
        bar.alignment = .center
        status.textColor = .white
        status.font = .systemFont(ofSize: 13)
        status.numberOfLines = 2
        status.textAlignment = .center
        status.text = "Log in, play a video, then tap Send to car or the AirPlay button and choose ScreenLink VPN Phone."
        let stack = UIStackView(arrangedSubviews: [bar, web, status])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -4),
            bar.heightAnchor.constraint(equalToConstant: 44),
        ])
        if let url = URL(string: "https://www.tiktok.com/foryou") { web.load(URLRequest(url: url)) }
        SLTikTokLauncher.log?("TIKTOK TEST: opened TikTok's website inside ScreenLink. No screen recording is used.")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.check(announce: false) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { shareLogin() }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        SLTikTokLauncher.log?("TIKTOK TEST: page did not load: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        status.text = "TikTok did not open: \(error.localizedDescription)"
        SLTikTokLauncher.log?("TIKTOK TEST: TikTok did not open: \(error.localizedDescription)")
    }

    /// Gives the video downloader the same login the page has (kept in memory on this phone only).
    private func shareLogin() {
        web.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let mine = cookies.filter { $0.domain.lowercased().contains("tiktok") }
            let text = mine.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            SLMediaHeaders.update(cookie: text, agent: Self.agent)
        }
    }

    private func check(announce: Bool) {
        web.evaluateJavaScript(Self.probe) { [weak self] result, _ in
            guard let self else { return }
            let state = result as? String ?? "none"
            if state != self.lastState || announce {
                self.lastState = state
                SLTikTokLauncher.log?("TIKTOK TEST: video on the page: \(state) (kind | playing | where it plays | AirPlay menu available).")
            }
            if state.hasPrefix("blob") {
                self.status.text = "This TikTok video is a kind that cannot be handed to the car (blob). Tell Claude this line."
            } else if state.contains("|airplay|") {
                self.status.text = "Sent by AirPlay. Look at the car screen."
            } else if state == "none" {
                self.status.text = "No video on the page yet. Open a video first."
            }
        }
    }

    @objc private func sendTapped() {
        shareLogin()
        check(announce: true)
        let open = "(function(){var vs=[].slice.call(document.querySelectorAll('video'));var mid=innerHeight/2,best=null,bd=1e9;vs.forEach(function(v){var r=v.getBoundingClientRect();if(r.height<50)return;var d=Math.abs((r.top+r.bottom)/2-mid);if(d<bd){bd=d;best=v;}});if(!best)return 'none';if(!best.webkitShowPlaybackTargetPicker)return 'nopicker';best.webkitShowPlaybackTargetPicker();return 'opened';})()"
        web.evaluateJavaScript(open) { [weak self] result, error in
            let answer = result as? String ?? (error?.localizedDescription ?? "no answer")
            SLTikTokLauncher.log?("TIKTOK TEST: Send to car → \(answer).")
            if answer == "opened" {
                self?.status.text = "Choose ScreenLink VPN Phone in the list."
            } else {
                self?.status.text = "The page did not open the AirPlay list (\(answer)). Use the AirPlay button at the top right instead."
            }
        }
    }

    @objc private func closeTapped() {
        web.evaluateJavaScript("[].slice.call(document.querySelectorAll('video')).forEach(function(v){v.pause();})", completionHandler: nil)
        dismiss(animated: true)
    }
}
