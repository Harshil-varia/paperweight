import AppKit

extension NSScreen {
    /// A stable identifier for this physical display.
    ///
    /// `NSScreen.screens` array indices are NOT stable — they change when a
    /// monitor is added, removed, or reordered — so they must never be used to
    /// key per-display state. `CGDirectDisplayID` (from the screen's
    /// `NSScreenNumber`) stays constant for a given physical display across
    /// hot-plug and reconfiguration, which is what we key panels and per-display
    /// settings on. Returns 0 only if the description is somehow unavailable.
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
