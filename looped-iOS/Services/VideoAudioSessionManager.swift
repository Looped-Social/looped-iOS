import AVFAudio
import Foundation

final class VideoAudioSessionManager {
    static let shared = VideoAudioSessionManager()

    private var requestingIds = Set<String>()
    private var hasConfiguredSession = false

    private init() {}

    func setWantsPlaybackAudio(_ wantsPlaybackAudio: Bool, id: String) {
        if Thread.isMainThread {
            setWantsPlaybackAudioOnMain(wantsPlaybackAudio, id: id)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setWantsPlaybackAudioOnMain(wantsPlaybackAudio, id: id)
            }
        }
    }

    private func setWantsPlaybackAudioOnMain(_ wantsPlaybackAudio: Bool, id: String) {
        let wasActive = !requestingIds.isEmpty

        if wantsPlaybackAudio {
            requestingIds.insert(id)
        } else {
            requestingIds.remove(id)
        }

        let isActive = !requestingIds.isEmpty
        guard isActive != wasActive || !hasConfiguredSession else { return }
        applySession(shouldBeActive: isActive)
        hasConfiguredSession = true
    }

    private func applySession(shouldBeActive: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if shouldBeActive {
                try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .duckOthers])
                try session.setActive(true)
            } else {
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
            }
        } catch {
            #if DEBUG
            print("LOOPED_AUDIO_SESSION error: \(error)")
            #endif
        }
    }
}
