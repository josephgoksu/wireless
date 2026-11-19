// Renders the app icon from the same parts the app draws with. `make icon`
import AppKit
import SwiftUI

struct Icon: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        VStack(spacing: 46) {
            DialGlass(frequency: 93.5, glow: 1, tuned: nil, names: false).frame(height: 210)
            HStack(spacing: 40) {
                ZStack {   // speaker cloth
                    RoundedRectangle(cornerRadius: 40).fill(Color(hex: 0x6b5236))
                    RadialGradient(colors: [Color(hex: 0xff9a3c).opacity(0.5), .clear], center: .bottom, startRadius: 0, endRadius: 360)
                    VStack(spacing: 44) { ForEach(0..<4, id: \.self) { _ in Capsule().fill(LinearGradient.brass).frame(height: 10) } }
                        .padding(.horizontal, 36)
                }
                .clipShape(RoundedRectangle(cornerRadius: 40))
                VStack(spacing: 34) {
                    MagicEye(signal: 0.8, glow: 1).frame(width: 150, height: 150)
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0x6a4428), Color(hex: 0x120803)], center: .init(x: 0.35, y: 0.3),
                                             startRadius: 2, endRadius: 90))
                        .overlay(Circle().fill(LinearGradient.brass).frame(width: 46))
                        .frame(width: 150, height: 150)
                }
            }
        }
        .padding(70)
        .frame(width: 824, height: 824)
        .background(Walnut().clipShape(shape))
        .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom), lineWidth: 8))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 16)
        .frame(width: 1024, height: 1024)
    }
}

@main
struct Main {
    @MainActor static func main() throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let renderer = ImageRenderer(content: Icon())
        var images: [[String: String]] = []
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                renderer.scale = Double(points * scale) / 1024
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                let png = NSBitmapImageRep(cgImage: renderer.cgImage!).representation(using: .png, properties: [:])!
                try png.write(to: dir.appendingPathComponent(name))
                images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
            }
        }
        let contents = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: .prettyPrinted)
        try contents.write(to: dir.appendingPathComponent("Contents.json"))
        try #"{"info":{"author":"xcode","version":1}}"#.write(to: dir.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    }
}
