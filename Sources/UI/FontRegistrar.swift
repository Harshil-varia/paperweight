import AppKit
import CoreText

/// Registers the bundled JetBrains Mono faces with the font manager at launch.
///
/// The TTFs ship inside the app bundle (Resources/Fonts in the project). Their
/// exact on-disk location can vary with how the resource folder is copied, so we
/// look in a few places rather than relying on a single fixed path or on
/// `ATSApplicationFontsPath`. Registration is idempotent and safe to call once.
enum FontRegistrar {
    private static let faces = [
        "JetBrainsMono-Regular",
        "JetBrainsMono-Medium",
        "JetBrainsMono-SemiBold",
        "JetBrainsMono-Bold",
    ]

    /// Whether the JetBrains Mono regular face resolved after registration.
    /// Computed once so the UI can cleanly fall back to a system monospace font.
    static let isJetBrainsMonoAvailable: Bool = {
        registerBundledFonts()
        return NSFont(name: "JetBrainsMono-Regular", size: 12) != nil
    }()

    /// Idempotently registers every bundled face. Errors for already-registered
    /// fonts are ignored; a genuinely missing file is logged, not fatal.
    static func registerBundledFonts() {
        for face in faces {
            guard let url = url(for: face) else {
                NSLog("[FontRegistrar] Missing bundled font: \(face).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is the common, harmless case; only log others.
                let code = (error?.takeUnretainedValue()).map { CFErrorGetCode($0) }
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    NSLog("[FontRegistrar] Could not register \(face): \(String(describing: error))")
                }
            }
        }
    }

    /// Resolves a face's URL, checking the `Fonts` subdirectory, the Resources
    /// root, and `Contents/Fonts` so we are robust to the copy layout.
    private static func url(for face: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: face, withExtension: "ttf", subdirectory: "Fonts") {
            return url
        }
        if let url = bundle.url(forResource: face, withExtension: "ttf") {
            return url
        }
        let contentsFonts = bundle.bundleURL
            .appendingPathComponent("Contents/Fonts/\(face).ttf")
        return FileManager.default.fileExists(atPath: contentsFonts.path) ? contentsFonts : nil
    }
}
