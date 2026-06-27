import Foundation
import CoreImage
import AppKit

class CoreImageNoiseGenerator: TextureGenerating {
    private let context: CIContext

    init() {
        self.context = CIContext()
    }

    func tile(for profile: TextureProfile, scale: CGFloat) -> TileImage? {
        let tileSize = CGFloat(profile.tileSize)

        // Core Image only supports white and value noise natively
        // For Phase 2, we generate a simple procedural fallback
        guard let noiseImage = generateSimpleNoise(size: tileSize, matteLift: profile.matteLift) else {
            return nil
        }

        guard let cgImage = context.createCGImage(noiseImage, from: noiseImage.extent) else {
            return nil
        }

        return TileImage(cgImage: cgImage, size: CGSize(width: tileSize, height: tileSize))
    }

    private func generateSimpleNoise(size: CGFloat, matteLift: Float) -> CIImage? {
        let extent = CGRect(x: 0, y: 0, width: size, height: size)

        // Use CIRandomGenerator as the base (sufficient for fallback)
        guard let randomImage = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return nil
        }

        // Crop to tile size
        let croppedRect = CIVector(cgRect: extent)
        guard let filter = CIFilter(name: "CICrop") else {
            return nil
        }
        filter.setValue(randomImage, forKey: kCIInputImageKey)
        filter.setValue(croppedRect, forKey: "inputRectangle")

        guard let croppedImage = filter.outputImage else {
            return nil
        }

        // Apply simple brightness boost using CIExposureAdjust
        let exposureFilter = CIFilter(name: "CIExposureAdjust")
        exposureFilter?.setValue(croppedImage, forKey: kCIInputImageKey)
        exposureFilter?.setValue(NSNumber(value: Double(matteLift)), forKey: kCIInputEVKey)

        return exposureFilter?.outputImage
    }
}
