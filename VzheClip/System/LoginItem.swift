import os
import ServiceManagement

@MainActor
enum LoginItem {
    private static let logger = Logger(subsystem: "com.vzh.VzheClip", category: "LoginItem")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Launch-at-login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
