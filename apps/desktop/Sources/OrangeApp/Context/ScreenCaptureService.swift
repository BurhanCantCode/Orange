import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ScreenCaptureService {
    func captureBase64JPEG(maxWidth: CGFloat = 1280, quality: CGFloat = 0.72) -> String? {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            return nil
        }

        let processed = resizeIfNeeded(image, maxWidth: maxWidth)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: 1,
        ]
        CGImageDestinationAddImage(destination, processed, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return Data(referencing: data).base64EncodedString()
    }

    private func resizeIfNeeded(_ image: CGImage, maxWidth: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > maxWidth else { return image }

        let scale = maxWidth / width
        let targetWidth = Int(width * scale)
        let targetHeight = Int(height * scale)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage() ?? image
    }
}
