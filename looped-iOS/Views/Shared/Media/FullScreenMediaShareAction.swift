import Foundation

enum FullScreenMediaShareAction {
    static let dismissDelay: TimeInterval = 0.2

    static func perform(
        dismiss: @escaping () -> Void,
        externalShare: (() -> Void)?,
        presentInlineShareSheet: @escaping () -> Void,
        schedule: ((@escaping () -> Void) -> Void)? = nil
    ) {
        guard let externalShare else {
            presentInlineShareSheet()
            return
        }

        dismiss()

        let shareScheduler = schedule ?? { action in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + dismissDelay,
                execute: action
            )
        }
        shareScheduler(externalShare)
    }
}
