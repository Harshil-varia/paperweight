import Foundation
import IOKit.ps

/// Monitors AC power vs battery status and reports changes.
protocol PowerMonitoring {
    func start()
    func stop()
}

class PowerMonitor: PowerMonitoring {
    weak var coordinator: AppCoordinator?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        // Create a notification source for power changes
        // Note: We can't use a closure that captures self because IOPSNotificationCreateRunLoopSource
        // expects a C function pointer, so we use a static function instead.
        let callbackPointer: IOPowerSourceCallbackType = { context in
            guard let contextPointer = context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(contextPointer).takeUnretainedValue()
            monitor.updateBatteryStatus()
        }

        let contextPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource(callbackPointer, contextPointer).takeRetainedValue() as CFRunLoopSource? else {
            return
        }

        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        updateBatteryStatus()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        runLoopSource = nil
    }

    deinit {
        stop()
    }

    /// Update the battery status based on current power source
    private func updateBatteryStatus() {
        guard let coordinator = coordinator else { return }

        if let sources = IOPSCopyPowerSourcesInfo().takeRetainedValue() as? [[String: Any]] {
            for source in sources {
                if let type = source[kIOPSTypeKey] as? String,
                   type == kIOPSInternalBatteryType {
                    if let state = source[kIOPSPowerSourceStateKey] as? String {
                        let onBattery = state == kIOPSBatteryPowerValue
                        coordinator.inputOnBattery = onBattery
                    }
                    return
                }
            }
        }

        // Default to not on battery if we can't determine
        coordinator.inputOnBattery = false
    }
}
