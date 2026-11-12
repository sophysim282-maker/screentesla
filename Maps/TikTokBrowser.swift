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

final class TikTokViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private static let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
    private var web: WKWebView!
    private let status = UILabel()
    private var timer: Timer?
    private var lastState = ""
    // Build 112: a sign-in window opened by the page (for example "Continue with Google").
    private var popup: WKWebView?
    private var popupBox: UIView?
    private var blockedLog = Date.distantPast
    private var stayLog = Date.distantPast
    private var autoOn = UserDefaults.standard.bool(forKey: "tiktokAuto")
    private let autoButton = UIButton(type: .system)
    private var lastMoved = 0
    private var scrolledEpoch = ""
    private var preparedCount = 0

    // Marks every video on the page as allowed for AirPlay and reports what kind of video is playing.
    private static let probe = """
    (function(){var vs=[].slice.call(document.querySelectorAll('video'));if(!vs.length)return 'none';
    var mid=innerHeight/2,best=null,bd=1e9;vs.forEach(function(v){v.setAttribute('x-webkit-airplay','allow');try{v.disableRemotePlayback=false;v.removeAttribute('disableremoteplayback');}catch(e){}
    var r=v.getBoundingClientRect();if(r.height<50)return;var d=Math.abs((r.top+r.bottom)/2-mid);if(d<bd){bd=d;best=v;}});
    if(!best)return 'none';var src=best.currentSrc||best.src||'';var kind=src.indexOf('blob:')===0?'blob':(src?'file':'nosrc');
    return kind+'|'+(best.paused?'paused':'playing')+'|'+(best.webkitCurrentPlaybackTargetIsWireless?'airplay':'local')+'|'+(best.webkitShowPlaybackTargetPicker?'picker':'nopicker');})()
    """


    // Build 113: runs inside the TikTok page. (1) Takes away the "Open app" asking: presses "Not now"
    // on such boxes and hides small "Open app" buttons. (2) Auto scroll: when the video in the middle
    // of the screen ends or starts over, moves to the next one.
    private static let helper = """
    (function(){if(window.__slTik)return;var S=window.__slTik={auto:false,last:null,lastT:0,since:Date.now(),nextAt:0,moved:0,hidden:0};
    function center(){var vs=[].slice.call(document.querySelectorAll('video')),mid=innerHeight/2,best=null,bd=1e9;vs.forEach(function(v){var r=v.getBoundingClientRect();if(r.height<50)return;var d=Math.abs((r.top+r.bottom)/2-mid);if(d<bd){bd=d;best=v;}});return best;}
    function scroller(el){for(var n=el;n&&n!==document.body&&n!==document.documentElement;n=n.parentElement){var st=getComputedStyle(n);if(/(auto|scroll)/.test(st.overflowY)&&n.scrollHeight>n.clientHeight+80)return n;}return null;}
    S.next=function(){var v=center(),done=false;
     // Build 122: first bring the next video on the page into the middle (works for every kind of scrolling list).
     if(v){var top=v.getBoundingClientRect().top,nx=null,nt=1e9;[].slice.call(document.querySelectorAll('video')).forEach(function(o){if(o===v)return;var t=o.getBoundingClientRect().top;if(t>top+50&&t<nt){nt=t;nx=o;}});
      if(nx){try{nx.scrollIntoView({behavior:'smooth',block:'center'});done=true;}catch(e){}}}
     if(!done){var sc=v&&scroller(v),h=sc?sc.clientHeight:innerHeight;try{(sc||window).scrollBy({top:h,behavior:'smooth'});}catch(e){(sc||window).scrollBy(0,h);}}
     // If the page did not move, press its own "next" control, then the down-arrow key.
     setTimeout(function(){if(center()!==v)return;var b=document.querySelector('[data-e2e=\"arrow-right\"],[data-e2e=\"video-switch-next\"],button[aria-label*=\"next\" i],button[aria-label*=\"Next\"]');if(b){b.click();return;}
      ['keydown','keyup'].forEach(function(k){document.dispatchEvent(new KeyboardEvent(k,{key:'ArrowDown',code:'ArrowDown',keyCode:40,which:40,bubbles:true}));});},1500);
     S.since=Date.now();S.moved++;};
    S.upcoming=function(){var v=center();if(!v)return '';var top=v.getBoundingClientRect().top,list=[];[].slice.call(document.querySelectorAll('video')).forEach(function(o){if(o===v)return;var s=o.currentSrc||o.src||'';if(s.indexOf('http')!==0)return;var t=o.getBoundingClientRect().top;if(t>top+50)list.push([t,s]);});list.sort(function(a,b){return a[0]-b[0];});return list.slice(0,2).map(function(x){return x[1];}).join('\\n');};
    function nag(){var no=/^(not now|maybe later|continue on web|continue in browser|stay on web|no thanks|not interested)$/i,ask=/open (the )?(tiktok|app)|get (the )?(tiktok )?app|tiktok app|in the app/i;
     [].slice.call(document.querySelectorAll('button,[role=button],a')).forEach(function(b){var t=(b.innerText||'').trim();if(!t||t.length>30||!no.test(t))return;var r=b.getBoundingClientRect();if(!r.width||!r.height)return;
      var box=b.closest('[role=dialog],[class*=odal],[class*=opup],[class*=heet],[class*=anner],[class*=rawer]');if(box&&ask.test(box.innerText||'')){b.click();S.hidden++;}});
     var open=/^(open app|open tiktok|open tiktok app|get app|get the app|get tiktok app|open in app|use app|use the app|watch in app)$/i;
     [].slice.call(document.querySelectorAll('a,button,[role=button],div,span')).forEach(function(e){if(e.__slHid||e.children.length>3)return;var t=(e.innerText||'').trim();if(!t||t.length>24||!open.test(t))return;var r=e.getBoundingClientRect();if(r.height&&r.height<140){e.style.setProperty('display','none','important');e.__slHid=1;S.hidden++;}});}
    setInterval(function(){try{nag();}catch(e){}if(!S.auto)return;var v=center();if(!v)return;if(v!==S.last){S.last=v;S.lastT=0;S.since=Date.now();return;}
     var t=v.currentTime||0,d=v.duration||0,wrapped=S.lastT>1&&t<S.lastT-1,ended=d>0&&t>=d-0.35,waited=(Date.now()-S.since)/1000;S.lastT=t;if(Date.now()<S.nextAt)return;
     if(wrapped||ended||(d>0&&waited>d+4)||(!(d>0)&&waited>60)){S.nextAt=Date.now()+2500;S.lastT=0;S.next();}},400);})();
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: Self.helper, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        web = WKWebView(frame: .zero, configuration: config)
        web.customUserAgent = Self.agent
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true

        let close = UIButton(type: .system)
        close.setTitle("‹ ScreenLink", for: .normal)
        close.titleLabel?.font = .boldSystemFont(ofSize: 16)
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        let title = UILabel()
        title.text = "TikTok"
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
        autoButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        autoButton.addTarget(self, action: #selector(autoTapped), for: .touchUpInside)
        showAuto()
        let bar = UIStackView(arrangedSubviews: [close, title, autoButton, send, route])
        bar.axis = .horizontal
        bar.spacing = 10
        bar.alignment = .center
        status.textColor = .white
        status.font = .systemFont(ofSize: 13)
        status.numberOfLines = 2
        status.textAlignment = .center
        status.text = "Log in, play a video, then tap Send to car and choose ScreenLink VPN Phone. If Google sign-in is refused, use email or username with a password."
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.check(announce: false) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { shareLogin() }

    /// Build 112: stay inside ScreenLink. A tap must never jump to the TikTok app or the App Store.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { decisionHandler(.cancel); return }
        let host = url.host?.lowercased() ?? ""
        let leavesApp = !["http", "https", "about", "blob", "data"].contains(scheme)
            || host.hasSuffix("onelink.me") || host.hasSuffix("app.link") || host == "apps.apple.com" || host == "itunes.apple.com"
        if leavesApp {
            if Date().timeIntervalSince(blockedLog) > 5 {
                blockedLog = Date()
                SLTikTokLauncher.log?("TIKTOK TEST: stopped a jump out of ScreenLink (\(scheme)://\(host)).")
                status.text = "Stayed in ScreenLink (the page tried to open the TikTok app)."
            }
            decisionHandler(.cancel)
            return
        }
        // Build 120: a tiktok.com address lets iOS open the TikTok app instead of this page (a "universal
        // link"), also when the page itself moves there after a tap, not only for a tapped link. This answer
        // means "open it here and do not offer it to another app" (the same answer other iOS browsers use).
        let stayHere = WKNavigationActionPolicy(rawValue: WKNavigationActionPolicy.allow.rawValue + 2) ?? .allow
        if navigationAction.targetFrame?.isMainFrame == true, Date().timeIntervalSince(stayLog) > 30 {
            stayLog = Date()
            SLTikTokLauncher.log?("TIKTOK: page moved to \(host); kept inside ScreenLink.")
        }
        decisionHandler(stayHere)
    }

    /// The page asks for a new window. Sign-in buttons do this: show it on top, inside ScreenLink.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        closePopup()
        let box = UIView()
        box.backgroundColor = .black
        box.translatesAutoresizingMaskIntoConstraints = false
        let done = UIButton(type: .system)
        done.setTitle("✕ Close sign-in window", for: .normal)
        done.titleLabel?.font = .boldSystemFont(ofSize: 16)
        done.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
        done.translatesAutoresizingMaskIntoConstraints = false
        let made = WKWebView(frame: .zero, configuration: configuration)   // this configuration keeps the link to the page that opened it
        made.customUserAgent = Self.agent
        made.navigationDelegate = self
        made.uiDelegate = self
        made.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(done)
        box.addSubview(made)
        view.addSubview(box)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: view.topAnchor), box.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            box.leadingAnchor.constraint(equalTo: view.leadingAnchor), box.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            done.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4), done.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            done.heightAnchor.constraint(equalToConstant: 40),
            made.topAnchor.constraint(equalTo: done.bottomAnchor, constant: 4), made.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            made.leadingAnchor.constraint(equalTo: guide.leadingAnchor), made.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
        ])
        popup = made
        popupBox = box
        SLTikTokLauncher.log?("TIKTOK TEST: the page opened a sign-in window (\(navigationAction.request.url?.host ?? "?")). Shown inside ScreenLink.")
        return made
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView === popup { closePopup() }
    }

    @objc private func closePopup() {
        guard popup != nil || popupBox != nil else { return }
        popupBox?.removeFromSuperview()
        popupBox = nil
        popup = nil
        shareLogin()
    }

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

    private func showAuto() {
        autoButton.setTitle(autoOn ? "Auto ON" : "Auto off", for: .normal)
        autoButton.setTitleColor(autoOn ? .systemGreen : .lightGray, for: .normal)
    }

    @objc private func autoTapped() {
        autoOn.toggle()
        UserDefaults.standard.set(autoOn, forKey: "tiktokAuto")
        showAuto()
        applyHelper()
        status.text = autoOn ? "Auto scroll ON: the next video starts when this one ends." : "Auto scroll off."
        SLTikTokLauncher.log?("TIKTOK TEST: auto scroll \(autoOn ? "ON" : "off").")
    }

    /// Keeps the page helper installed (TikTok changes pages without reloading) and in the chosen mode.
    private func applyHelper() {
        let js = Self.helper + ";window.__slTik.auto=\(autoOn ? "true" : "false");window.__slTik.moved+'|'+window.__slTik.hidden"
        web.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self, let text = result as? String else { return }
            let moved = Int(text.split(separator: "|").first ?? "") ?? 0
            if moved != self.lastMoved {
                self.lastMoved = moved
                SLTikTokLauncher.log?("TIKTOK TEST: auto scroll moved to the next video (\(moved) so far).")
            }
        }
    }

    /// Build 122: ScreenLink itself knows where the car is in the video. When the car reaches the end,
    /// move the page to the next video. This does not depend on what the page thinks while AirPlay is on.
    private func followCar() {
        guard autoOn, let cast = NSClassFromString("MediaCast") as? NSObject.Type,
              let info = cast.perform(NSSelectorFromString("currentProgress"))?.takeUnretainedValue() as? [String: Any],
              (info["active"] as? Bool) == true, (info["kind"] as? String) == "file",
              let epoch = info["epoch"] as? String, epoch != scrolledEpoch,
              let position = info["position"] as? Double, let duration = info["duration"] as? Double,
              duration > 1, position >= duration - 0.9 else { return }
        scrolledEpoch = epoch
        let js = "(function(){var S=window.__slTik;if(!S)return 'no helper';if(Date.now()<S.nextAt)return 'just moved';S.nextAt=Date.now()+4000;S.lastT=0;S.next();return 'moved';})()"
        web.evaluateJavaScript(js) { result, _ in
            SLTikTokLauncher.log?(String(format: "TIKTOK: the car reached the end (%.0f of %.0f s). Auto scroll: %@.", position, duration, result as? String ?? "no answer"))
        }
    }

    /// Build 122: the next videos on the page are downloaded to the phone early, so they start fast in the car.
    private func prepareNext() {
        web.evaluateJavaScript("window.__slTik&&window.__slTik.upcoming?window.__slTik.upcoming():''") { [weak self] result, _ in
            guard let self, let text = result as? String, !text.isEmpty, let cast = NSClassFromString("MediaCast") as? NSObject.Type else { return }
            let list = text.split(separator: "\n").map(String.init)
            for address in list { _ = cast.perform(NSSelectorFromString("prefetchFile:"), with: address) }
            if list.count != self.preparedCount {
                self.preparedCount = list.count
                SLTikTokLauncher.log?("TIKTOK: preparing the next \(list.count) video(s) on the phone.")
            }
        }
    }

    private func check(announce: Bool) {
        applyHelper()
        followCar()
        shareLogin()
        prepareNext()
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
