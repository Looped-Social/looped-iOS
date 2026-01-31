import AVFAudio
import Foundation

final class VideoAudioSessionManager {
    static let shared = VideoAudioSessionManager()

    private var requestingIds = Set<String>()

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
        guard isActive != wasActive else { return }
        applySession(shouldBeActive: isActive)
    }

    private func applySession(shouldBeActive: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if shouldBeActive {
                try session.setCategory(.playback, mode: .moviePlayback, options: [.duckOthers])
                try session.setActive(true)
            } else {
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
                try session.setCategory(.soloAmbient, mode: .default, options: [])
            }
        } catch {
            #if DEBUG
            print("LOOPED_AUDIO_SESSION error: \(error)")
            #endif
        }
    }
}
