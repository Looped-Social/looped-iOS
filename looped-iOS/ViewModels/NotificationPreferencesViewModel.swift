import Foundation

@MainActor
class NotificationPreferencesViewModel: ObservableObject {
    @Published var preferences: NotificationPreferencesDTO?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let notificationService: NotificationServiceProtocol

    init(notificationService: NotificationServiceProtocol = NotificationService()) {
        self.notificationService = notificationService
    }

    func loadPreferences() async {
        isLoading = true
        defer { isLoading = false }
        do {
            preferences = try await notificationService.fetchPreferences()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setChannelEnabled(_ channel: NotificationPreferenceChannel, isOn: Bool) async {
        let update = makeChannelEnabledUpdate(channel: channel, isOn: isOn)
        await applyUpdate(update) { preferences in
            var channelPrefs = preferences.channels.channel(channel)
            channelPrefs.enabled = isOn
            preferences.channels.setChannel(channel, to: channelPrefs)
        }
    }

    func setTypeEnabled(
        channel: NotificationPreferenceChannel,
        type: NotificationPreferenceType,
        isOn: Bool
    ) async {
        let update = makeTypeUpdate(channel: channel, type: type, isOn: isOn)
        await applyUpdate(update) { preferences in
            var channelPrefs = preferences.channels.channel(channel)
            channelPrefs.types.set(isOn, for: type)
            preferences.channels.setChannel(channel, to: channelPrefs)
        }
    }

    func setTypeEnabled(
        type: NotificationPreferenceType,
        isOn: Bool,
        channels: [NotificationPreferenceChannel] = NotificationPreferenceChannel.allCases
    ) async {
        let update = makeTypeUpdate(channels: channels, type: type, isOn: isOn)
        await applyUpdate(update) { preferences in
            for channel in channels {
                var channelPrefs = preferences.channels.channel(channel)
                channelPrefs.types.set(isOn, for: type)
                preferences.channels.setChannel(channel, to: channelPrefs)
            }
        }
    }

    func setPrivacyMode(_ mode: NotificationPrivacyMode) async {
        let update = makePrivacyModeUpdate(mode: mode)
        await applyUpdate(update) { preferences in
            preferences.privacyMode = mode
        }
    }

    private func applyUpdate(
        _ update: NotificationPreferencesUpdateRequest,
        applyLocal: (inout NotificationPreferencesDTO) -> Void
    ) async {
        guard var current = preferences else { return }
        let previous = current
        applyLocal(&current)
        preferences = current
        do {
            preferences = try await notificationService.updatePreferences(update)
            errorMessage = nil
        } catch {
            preferences = previous
            errorMessage = error.localizedDescription
        }
    }

    private func makeChannelEnabledUpdate(
        channel: NotificationPreferenceChannel,
        isOn: Bool
    ) -> NotificationPreferencesUpdateRequest {
        var channels = NotificationChannelsUpdateDTO()
        channels.setChannel(channel, update: NotificationChannelUpdateDTO(enabled: isOn, types: nil))
        return NotificationPreferencesUpdateRequest(channels: channels)
    }

    private func makeTypeUpdate(
        channel: NotificationPreferenceChannel,
        type: NotificationPreferenceType,
        isOn: Bool
    ) -> NotificationPreferencesUpdateRequest {
        var types = NotificationTypePreferencesUpdateDTO()
        types.set(isOn, for: type)
        let channelUpdate = NotificationChannelUpdateDTO(enabled: nil, types: types)
        var channels = NotificationChannelsUpdateDTO()
        channels.setChannel(channel, update: channelUpdate)
        return NotificationPreferencesUpdateRequest(channels: channels)
    }

    private func makeTypeUpdate(
        channels targetChannels: [NotificationPreferenceChannel],
        type: NotificationPreferenceType,
        isOn: Bool
    ) -> NotificationPreferencesUpdateRequest {
        var types = NotificationTypePreferencesUpdateDTO()
        types.set(isOn, for: type)
        let channelUpdate = NotificationChannelUpdateDTO(enabled: nil, types: types)
        var channels = NotificationChannelsUpdateDTO()
        for channel in targetChannels {
            channels.setChannel(channel, update: channelUpdate)
        }
        return NotificationPreferencesUpdateRequest(channels: channels)
    }

    private func makePrivacyModeUpdate(mode: NotificationPrivacyMode) -> NotificationPreferencesUpdateRequest {
        NotificationPreferencesUpdateRequest(privacyMode: mode, channels: NotificationChannelsUpdateDTO())
    }
}
