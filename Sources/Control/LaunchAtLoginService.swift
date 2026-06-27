import ServiceManagement

/// Manages launch-at-login via SMAppService.
protocol LaunchAtLoginManaging {
    func setLaunchAtLogin(_ enabled: Bool) throws
    func isEnabledAtLogin() -> Bool
}

class LaunchAtLoginService: LaunchAtLoginManaging {
    /// Enable or disable launch at login
    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Check if app is set to launch at login
    func isEnabledAtLogin() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
