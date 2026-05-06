import AVFoundation
import Foundation
import Observation
import OSLog

/// 录音 + 回放的简单封装。
///
/// - 录音：写入临时文件（M4A / AAC），停止时读回 `Data`
/// - 回放：从内存 `Data` 直接播放
/// - 状态全部 `@Observable`，UI 可直接绑定
@Observable
@MainActor
final class AudioRecorderService: NSObject {

    private static let log = Logger(subsystem: "com.personal.babytimeline", category: "Audio")

    enum State {
        case idle
        case recording(elapsed: TimeInterval)
        case finishedRecording(data: Data, duration: TimeInterval)
        case playing(progress: Double)  // 0...1
        case failed(String)
    }

    private(set) var state: State = .idle

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?

    // MARK: - 权限

    /// 询问麦克风权限。已授予直接返回 true。
    func requestPermission() async -> Bool {
        if #available(iOS 17, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - 录音

    /// 开始录音。需要先 `requestPermission()` 返回 true。
    func startRecording() {
        stopAll()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            state = .failed("音频会话启用失败：\(error.localizedDescription)")
            Self.log.error("Audio session error: \(error.localizedDescription, privacy: .public)")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appending(path: "rec-\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            r.isMeteringEnabled = false
            guard r.record() else {
                state = .failed("录音启动失败")
                return
            }
            recorder = r
            recordingStartedAt = .now
            state = .recording(elapsed: 0)
            startTickTimer()
        } catch {
            state = .failed("录音器创建失败：\(error.localizedDescription)")
            Self.log.error("Recorder init error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 停止录音，把数据读回内存。
    func stopRecording() {
        guard let recorder, recorder.isRecording else { return }
        let duration = recorder.currentTime
        recorder.stop()
        stopTickTimer()
        self.recorder = nil
        recordingStartedAt = nil

        guard let url = recordingURL else {
            state = .failed("录音文件丢失")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
            state = .finishedRecording(data: data, duration: duration)
        } catch {
            state = .failed("读取录音失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 回放

    func play(_ data: Data) {
        stopAll()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            p.prepareToPlay()
            guard p.play() else {
                state = .failed("播放启动失败")
                return
            }
            player = p
            state = .playing(progress: 0)
            startTickTimer()
        } catch {
            state = .failed("播放失败：\(error.localizedDescription)")
        }
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        stopTickTimer()
        state = .idle
    }

    // MARK: - 通用

    func stopAll() {
        recorder?.stop()
        recorder = nil
        player?.stop()
        player = nil
        stopTickTimer()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        recordingStartedAt = nil
        state = .idle
    }

    // MARK: - Timer

    private func startTickTimer() {
        stopTickTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTickTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if let recorder, recorder.isRecording {
            let elapsed = recorder.currentTime
            state = .recording(elapsed: elapsed)
        } else if let player, player.isPlaying {
            let progress = player.duration > 0 ? player.currentTime / player.duration : 0
            state = .playing(progress: progress)
        }
    }
}

// MARK: - Delegate

extension AudioRecorderService: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // 主动 stopRecording 时这里不需要做事；这里只处理「自然到时」。
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stopTickTimer()
            self?.player = nil
            self?.state = .idle
        }
    }
}
