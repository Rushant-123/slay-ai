//
//  Extensions.swift
//  SnatchShot
//
//  Created by Assistant on 20/09/25.
//

import Foundation
import UIKit

// UIImage extension to fix orientation issues
extension UIImage {
    func fixedOrientation() -> UIImage? {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func rotate90DegreesClockwise() -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        let rotatedSize = CGSize(width: size.height, height: size.width)
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Move to the center of the context
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        // Rotate by 90 degrees clockwise
        context.rotate(by: .pi / 2)
        // Move back to draw the image centered
        context.translateBy(x: -size.width / 2, y: -size.height / 2)

        // Draw the image
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func rotate90DegreesCounterclockwise() -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        let rotatedSize = CGSize(width: size.height, height: size.width)
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Move to the center of the context
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        // Rotate by 90 degrees counterclockwise
        context.rotate(by: -.pi / 2)
        // Move back to draw the image centered
        context.translateBy(x: -size.width / 2, y: -size.height / 2)

        // Draw the image
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Smart rotation based on image orientation - rotates to upright
    func rotateToCorrectOrientation(isFrontCamera: Bool = false) -> UIImage {
        print("🔄 rotateToCorrectOrientation called")
        print("🔄 Image orientation: \(imageOrientation.rawValue) (\(imageOrientation))")
        print("🔄 Image size: \(size)")

        // Rotate based on the image's orientation property
        switch imageOrientation {
        case .up:
            print("✅ Image already upright")
            return self
        case .down:
            print("🔄 Rotating 180° (image is upside down)")
            return rotate180Degrees() ?? self
        case .left:
            print("🔄 Rotating 90° clockwise (image is rotated left)")
            return rotate90DegreesClockwise() ?? self
        case .right:
            print("🔄 Rotating 90° counterclockwise (image is rotated right)")
            return rotate90DegreesCounterclockwise() ?? self
        case .upMirrored:
            print("🔄 Rotating 180° + mirror (image is mirrored)")
            return rotate180Degrees()?.flipHorizontally() ?? self
        case .downMirrored:
            print("🔄 Rotating 180° + mirror (image is mirrored)")
            return rotate180Degrees()?.flipHorizontally() ?? self
        case .leftMirrored:
            print("🔄 Rotating 90° clockwise + mirror (image is mirrored)")
            return rotate90DegreesClockwise()?.flipHorizontally() ?? self
        case .rightMirrored:
            print("🔄 Rotating 90° counterclockwise + mirror (image is mirrored)")
            return rotate90DegreesCounterclockwise()?.flipHorizontally() ?? self
        @unknown default:
            print("❓ Unknown orientation, returning as-is")
            return self
        }
    }


    /// Rotate image 180 degrees
    func rotate180Degrees() -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Move to center and rotate 180 degrees
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: .pi)
        context.translateBy(x: -size.width / 2, y: -size.height / 2)

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Rotate image 270 degrees clockwise (90 degrees counter-clockwise)
    func rotate270DegreesClockwise() -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        let rotatedSize = CGSize(width: size.height, height: size.width)
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Move to center, rotate 270° clockwise, then translate back
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        context.rotate(by: 3 * .pi / 2) // 270° clockwise
        context.translateBy(x: -size.width / 2, y: -size.height / 2)

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Flip image horizontally (correct front camera mirroring)
    func flipHorizontally() -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Flip horizontally by scaling x by -1
        context.translateBy(x: size.width, y: 0)
        context.scaleBy(x: -1, y: 1)

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

