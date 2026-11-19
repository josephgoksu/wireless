import AVFoundation
import MediaPlayer
import Observation

/// The set itself: a needle on a dial, valves that take a moment to warm up, and real static
/// between stations. The BBC stream fades in only as the needle finds the station.
@MainActor @Observable
final class Radio {
    static let shared = Radio()
    static let capture = 0.8   // MHz either side of a station where you start to hear it

    private(set) var frequency: Double
    private(set) var isOn = false
    private(set) var glow = 0.0       // the valves as you see them, flicker and all
    private(set) var signal = 0.0     // drives the magic eye
    private(set) var receiving = false
    private(set) var onAir: OnAir?
    var volume: Double { didSet { UserDefaults.standard.set(volume, forKey: "volume") } }

    private let player = AVPlayer()
    private let hiss = Hiss()
    private var warmth = 0.0
    private var target: Double?          // where a preset key is sweeping the needle
    private var loaded: Station?
    private var abroad = false           // outside the UK only the international stream plays
    private var touched = Date.distantPast
    private var heard = Date.distantPast
    private var fetched = Date.distantPast

    var tuned: Station? {
        Station.nearest(to: frequency).flatMap { abs($0.frequency - frequency) < Self.capture ? $0 : nil }
    }
    /// The key that stays pressed: where the needle is heading, or where it rests.
    var latched: Station? { target.flatMap { t in Station.all.first { $0.frequency == t } } ?? tuned }

    private init() {
        frequency = UserDefaults.standard.object(forKey: "frequency") as? Double ?? 93.5
        volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.7
        setUpRemoteCommands()
        Task {
            while true {
                tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: Controls

    func power(_ on: Bool) { isOn = on; publishNowPlaying() }

    func press(_ station: Station) {
        isOn = true
        target = station.frequency
        publishNowPlaying()
    }

    func tune(by delta: Double) {
        target = nil
        touched = .now
        frequency = min(max(frequency + delta, Station.band.lowerBound), Station.band.upperBound)
    }

    func step(_ direction: Int) {
        let here = target ?? frequency
        let next = direction > 0 ? Station.all.first { $0.frequency > here + 0.05 } : Station.all.last { $0.frequency < here - 0.05 }
        if let next { press(next) }
    }

    /// wireless://tune/bbc_radio_fourfm, wireless://off, wireless://on
    func open(_ url: URL) {
        switch url.host() {
        case "tune": Station.named(url.lastPathComponent).map(press)
        case "off": power(false)
        default: power(true)
        }
    }

    // MARK: The 60 Hz heartbeat

    private func tick() {
        let now = Date.now
        warmth = isOn ? min(1, warmth + 0.016 / 2.2) : max(0, warmth - 0.016 / 0.7)

        if let t = target {   // the dial cord: quick through the middle, gentle as it arrives
            frequency += min(max((t - frequency) * 0.12, -0.35), 0.35)
            if abs(t - frequency) < 0.004 { frequency = t; target = nil }
        }

        let station = tuned
        if isOn, let station, station != loaded, target == nil, now.timeIntervalSince(touched) > 0.25 { load(station) }
        if station != nil, station == loaded { heard = now }
        if loaded != nil, (!isOn && warmth == 0) || now.timeIntervalSince(heard) > 1.5 { unload() }
        if player.currentItem?.status == .failed, !abroad, let s = loaded {
            abroad = true   // the UK stream is geo-fenced; fall back to the international one
            loaded = nil
            load(s)
        }
        if isOn, let s = loaded, now.timeIntervalSince(fetched) > 30 {
            fetched = now
            Task {
                let info = await OnAir.fetch(s)
                guard loaded == s else { return }
                onAir = info
                publishNowPlaying()
            }
        }

        let closeness = station.map { 1 - abs($0.frequency - frequency) / Self.capture } ?? 0
        let playing = player.timeControlStatus == .playing && station != nil && station == loaded
        let clarity = playing ? closeness : 0
        let flicker = warmth > 0 && warmth < 1 ? Double.random(in: -0.15...0.05) * (1 - warmth) : 0
        update(\.receiving, playing)
        update(\.signal, (closeness * (playing ? 1 : 0.3) * 100).rounded() / 100)
        update(\.glow, max(0, warmth * warmth + flicker))

        let level = Float(volume * warmth)
        player.volume = level * Float(clarity * clarity)
        hiss.noise = level * Float(1 - clarity) * 0.22
        hiss.whistle = level * Float(closeness * (1 - clarity)) * 0.05
        hiss.pitch = Float(abs((station?.frequency ?? frequency) - frequency) * 3000)   // zero beat dead on the station
        hiss.hum = level * 0.012
        if warmth > 0 { hiss.start() } else { hiss.stop() }
    }

    /// Observation re-renders on every write, so only write what changed.
    private func update<T: Equatable>(_ key: ReferenceWritableKeyPath<Radio, T>, _ value: T) {
        if self[keyPath: key] != value { self[keyPath: key] = value }
    }

    private func load(_ station: Station) {
        loaded = station
        onAir = nil
        heard = .now
        fetched = .distantPast
        player.replaceCurrentItem(with: AVPlayerItem(url: station.stream(uk: !abroad)))
        player.play()
        UserDefaults.standard.set(station.frequency, forKey: "frequency")
        publishNowPlaying()
    }

    private func unload() {
        player.replaceCurrentItem(with: nil)
        loaded = nil
        onAir = nil
        publishNowPlaying()
    }

    // MARK: Media keys and Control Center

    private func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        func on(_ command: MPRemoteCommand, _ action: @escaping @MainActor (Radio) -> Void) {
            command.addTarget { @Sendable _ in
                Task { @MainActor in action(.shared) }
                return .success
            }
        }
        on(center.togglePlayPauseCommand) { $0.power(!$0.isOn) }
        on(center.playCommand) { $0.power(true) }
        on(center.pauseCommand) { $0.power(false) }
        on(center.stopCommand) { $0.power(false) }
        on(center.nextTrackCommand) { $0.step(1) }
        on(center.previousTrackCommand) { $0.step(-1) }
    }

    private func publishNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard isOn, let s = loaded ?? latched else {
            center.playbackState = .stopped
            return
        }
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: onAir?.track ?? onAir?.programme ?? s.title,
            MPMediaItemPropertyArtist: onAir?.track != nil ? "\(s.title) · \(onAir!.programme)" : s.title,
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
        center.playbackState = .playing
    }
}

/// Synthesises what lives between stations: hiss, crackle, the heterodyne whistle, and a little 50 Hz mains hum.
final class Hiss: @unchecked Sendable {
    // ponytail: plain floats shared with the audio thread. A torn read costs one odd sample, not worth a lock.
    var noise: Float = 0, whistle: Float = 0, pitch: Float = 0, hum: Float = 0

    private let engine = AVAudioEngine()
    private var n: Float = 0, w: Float = 0, p: Float = 0, h: Float = 0   // smoothed copies, audio thread only
    private var seed: UInt32 = 0x2545F491, rumble: Float = 0, crackle: Float = 0, phase: Float = 0, humPhase: Float = 0

    init() {
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let source = AVAudioSourceNode { [unowned self] _, _, frames, buffers in
            render(Int(frames), UnsafeMutableAudioBufferListPointer(buffers), Float(rate))
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
    }

    func start() { if !engine.isRunning { try? engine.start() } }
    func stop() { if engine.isRunning { engine.pause() } }

    private func render(_ frames: Int, _ buffers: UnsafeMutableAudioBufferListPointer, _ rate: Float) {
        for i in 0..<frames {
            n += (noise - n) * 0.0005
            w += (whistle - w) * 0.0005
            p += (pitch - p) * 0.002
            h += (hum - h) * 0.0005
            seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5   // xorshift: no locks, no allocations
            let white = Float(seed) / Float(UInt32.max) * 2 - 1
            rumble += (white - rumble) * 0.06
            if seed % 40_000 == 0 { crackle = white }
            crackle *= 0.994
            phase = (phase + p / rate).truncatingRemainder(dividingBy: 1)
            humPhase = (humPhase + 50 / rate).truncatingRemainder(dividingBy: 1)
            let sample = n * (white * 0.45 + rumble * 1.6 + crackle * 2.5)
                + w * sin(2 * .pi * phase)
                + h * (sin(2 * .pi * humPhase) + 0.35 * sin(4 * .pi * humPhase))
            for buffer in buffers { buffer.mData!.assumingMemoryBound(to: Float.self)[i] = sample }
        }
    }
}
