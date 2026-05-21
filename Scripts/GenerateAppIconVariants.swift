import AppKit
import Foundation

struct CropSpec {
    let name: String
    let x: CGFloat
    let y: CGFloat
    let side: CGFloat
    let rounded: Bool
}

enum GenerateAppIconVariants {
    static func run() throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("Usage: swift Scripts/GenerateAppIconVariants.swift <input> <outputDir>\n", stderr)
            exit(1)
        }

        let inputPath = CommandLine.arguments[1]
        let outputDir = CommandLine.arguments[2]
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputDir, isDirectory: true)

        guard
            let image = NSImage(contentsOf: inputURL),
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let cgImage = bitmap.cgImage
        else {
            fputs("Failed to load image at \(inputPath)\n", stderr)
            exit(1)
        }

        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let height = CGFloat(cgImage.height)

        let crops = [
            CropSpec(name: "IconAntiKaos2-light.png", x: 284, y: 18, side: 686, rounded: true),
            CropSpec(name: "IconAntiKaos2-dark.png", x: 30, y: 716, side: 566, rounded: false),
            CropSpec(name: "IconAntiKaos2-tinted.png", x: 658, y: 716, side: 566, rounded: false)
        ]

        for crop in crops {
            let rect = CGRect(
                x: crop.x,
                y: height - crop.y - crop.side,
                width: crop.side,
                height: crop.side
            ).integral

            guard let cropped = cgImage.cropping(to: rect) else {
                fputs("Failed to crop \(crop.name)\n", stderr)
                exit(1)
            }

            guard let scaled = resize(cgImage: cropped, size: CGSize(width: 1024, height: 1024), rounded: crop.rounded) else {
                fputs("Failed to resize \(crop.name)\n", stderr)
                exit(1)
            }

            let rep = NSBitmapImageRep(cgImage: scaled)
            rep.size = NSSize(width: 1024, height: 1024)

            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                fputs("Failed to encode \(crop.name)\n", stderr)
                exit(1)
            }

            try pngData.write(to: outputURL.appendingPathComponent(crop.name), options: .atomic)
        }

        let oldJPEG = outputURL.appendingPathComponent("IconAntiKaos2.jpg")
        if FileManager.default.fileExists(atPath: oldJPEG.path) {
            try? FileManager.default.removeItem(at: oldJPEG)
        }

        print("Generated app icon variants in \(outputDir)")
    }

    static func resize(cgImage: CGImage, size: CGSize, rounded: Bool) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high

        if rounded {
            let radius = min(size.width, size.height) * 0.22
            let path = CGPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )
            context.addPath(path)
            context.clip()
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}

do {
    try GenerateAppIconVariants.run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
