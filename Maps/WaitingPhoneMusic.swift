import AVFoundation

/// Build 161: waiting music through the phone (its speaker or Bluetooth to the car), instead of the car
/// website. Plays while ScreenLink is on and the car shows no video, fades out when the car starts the
/// video (MediaCast posts SLCarVideoEvent), and goes on from the same place next time.
@objc(SLWaitingPhoneMusic)
final class SLWaitingPhoneMusic: NSObject {
    @objc static let shared = SLWaitingPhoneMusic()
    private var player: AVAudioPlayer?
    private var loadedFile = ""
    private var carPlaying = false
    private var sharing = false
    private var timer: Timer?

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(forName: Notification.Name("SLCarVideoEvent"), object: nil, queue: .main) { [weak self] note in
            let event = note.object as? String ?? ""
            self?.carPlaying = event == "playing"
            self?.update()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.update() }
    }

    /// Called by main.m when sharing starts (YouTube only) and when Disconnect all stops it.
    @objc func setSharing(_ on: Bool) { sharing = on; if !on { carPlaying = false }; update() }

    private func update() {
        let store = SLWaitingStore.self
        let want = sharing && !carPlaying && store.musicOn && store.musicOutput == "phone" && !store.musicFile.isEmpty
        if want {
            if loadedFile != store.musicFile || player == nil { load() }
            guard let player else { return }
            let target = Float(store.musicVolume) / 100
            if !player.isPlaying {
                player.volume = 0
                player.play()
                player.setVolume(target, fadeDuration: 1.5)
            } else if abs(player.volume - target) > 0.01 {
                player.setVolume(target, fadeDuration: 0.3)
            }
        } else if let player, player.isPlaying, player.volume > 0 {
            player.setVolume(0, fadeDuration: 1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                guard let self, let p = self.player, p.volume <= 0.01 else { return }
                p.pause()
                UserDefaults.standard.set(p.currentTime, forKey: "waitingPhoneMusicPos")
            }
        }
    }

    private func load() {
        let store = SLWaitingStore.self
        let url = store.musicFile == store.bundledSong ? store.bundledURL : store.folder.appendingPathComponent(store.musicFile)
        guard let url, let made = try? AVAudioPlayer(contentsOf: url) else { player = nil; return }
        made.numberOfLoops = -1
        made.prepareToPlay()
        let at = UserDefaults.standard.double(forKey: "waitingPhoneMusicPos")
        if at > 0 && at < made.duration { made.currentTime = at }
        player = made
        loadedFile = store.musicFile
    }
}
