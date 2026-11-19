import SwiftUI

// The parts bin: everything the app and the widget both draw. No image assets, it's all SwiftUI.

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
    static let walnut = Color(hex: 0x5c3519)
    static let walnutDark = Color(hex: 0x2b1608)
    static let walnutLight = Color(hex: 0x7d4b25)
    static let ivory = Color(hex: 0xf4ecd6)
    static let paper = Color(hex: 0xefe2bf)
    static let ink = Color(hex: 0x2b1b0e)
    static let needle = Color(hex: 0xc4301c)
    static let amber = Color(hex: 0xffc35c)
    static let phosphor = Color(hex: 0x62ff9e)
}

extension LinearGradient {
    static var brass: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xf7e4a3), Color(hex: 0xc79d46), Color(hex: 0x8a6421), Color(hex: 0xe8cc7a)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Font {
    static func gill(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? "GillSans-SemiBold" : "GillSans", size: size) }
    static func typewriter(_ size: CGFloat, bold: Bool = false) -> Font { .custom(bold ? "AmericanTypewriter-Semibold" : "AmericanTypewriter", size: size) }
}

/// French-polished walnut, with grain that's the same every time you draw it.
struct Walnut: View {
    var body: some View {
        LinearGradient(colors: [.walnutLight, .walnut, .walnutDark], startPoint: .top, endPoint: .bottom)
            .overlay(Canvas { ctx, size in
                var seed: UInt64 = 1953
                func random() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double(seed >> 11) / Double(UInt64(1) << 53)
                }
                for i in 0..<110 {
                    let y0 = Double(i) / 110 * size.height
                    let amp = 1 + random() * 7, wave = 0.003 + random() * 0.012, phase = random() * 6
                    var grain = Path()
                    grain.move(to: CGPoint(x: 0, y: y0))
                    for x in stride(from: 0, through: size.width, by: 5) {
                        grain.addLine(to: CGPoint(x: x, y: y0 + sin(x * wave + phase) * amp))
                    }
                    ctx.stroke(grain, with: .color(.black.opacity(0.04 + random() * 0.13)), lineWidth: 0.5 + random() * 1.6)
                }
            })
    }
}

/// The tuning scale on backlit glass, with the station names printed on like a 1950s set.
struct DialGlass: View {
    var frequency: Double
    var glow: Double          // 0 dark glass … 1 lit valves
    var tuned: Station?
    var names = true

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let pad = size.width * 0.045
            let band = Station.band
            let x = { (f: Double) -> CGFloat in pad + (f - band.lowerBound) / (band.upperBound - band.lowerBound) * (size.width - 2 * pad) }
            let type = max(6, size.height / 8)
            let roomy = size.width > 300   // a widget-sized dial prints every other number and drops the band labels

            ZStack {
                Color(hex: 0x5d4e31)
                RadialGradient(colors: [Color(hex: 0xfff1c8), .amber, Color(hex: 0xb8722a)],
                               center: .center, startRadius: 0, endRadius: size.width * 0.6)
                    .opacity(glow)

                Canvas { ctx, canvas in
                    let base = canvas.height * 0.86
                    for step in 0...Int((band.upperBound - band.lowerBound) * 2) {
                        let f = band.lowerBound + Double(step) * 0.5
                        let major = f.truncatingRemainder(dividingBy: 2) == 0
                        let h = canvas.height * (major ? 0.2 : f == f.rounded() ? 0.13 : 0.07)
                        ctx.fill(Path(CGRect(x: x(f) - 0.6, y: base - h, width: 1.2, height: h)), with: .color(.ink.opacity(0.85)))
                        if major, roomy || f.truncatingRemainder(dividingBy: 4) == 0 {
                            ctx.draw(Text("\(Int(f))").font(.gill(type)).foregroundStyle(Color.ink),
                                     at: CGPoint(x: x(f), y: base - h - type * 0.75))
                        }
                    }
                    ctx.fill(Path(CGRect(x: pad, y: base, width: canvas.width - 2 * pad, height: 1.2)), with: .color(.ink))
                    guard roomy else { return }
                    ctx.draw(Text("MHz").font(.gill(type * 0.8)).foregroundStyle(Color.ink.opacity(0.7)),
                             at: CGPoint(x: canvas.width - pad, y: canvas.height * 0.94))
                    ctx.draw(Text("VHF · FM").font(.gill(type * 0.8)).foregroundStyle(Color.ink.opacity(0.7)),
                             at: CGPoint(x: pad + type * 1.6, y: canvas.height * 0.94))
                }

                if names {
                    ForEach(Station.all) { s in
                        Text(s.name)
                            .font(.gill(type * 1.3, bold: true))
                            .foregroundStyle(s == tuned ? Color.needle : .ink)
                            .position(x: x(s.frequency), y: size.height * 0.2)
                    }
                }

                Capsule()
                    .fill(Color.needle)
                    .frame(width: max(2, size.width / 240), height: size.height * 0.86)
                    .shadow(color: .needle.opacity(0.7 * glow), radius: 3)
                    .position(x: x(frequency), y: size.height / 2)

                LinearGradient(stops: [.init(color: .white.opacity(0.22), location: 0), .init(color: .clear, location: 0.45),
                                       .init(color: .black.opacity(0.18), location: 1)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(LinearGradient.brass))
        .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
        .accessibilityElement()
        .accessibilityLabel("Tuning dial")
        .accessibilityValue(String(format: "%.1f megahertz%@", frequency, tuned.map { ", \($0.title)" } ?? ""))
    }
}

/// An EM84-style magic eye. The dark wedge closes as the signal locks on.
struct MagicEye: View {
    var signal: Double
    var glow: Double

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            func disc(_ radius: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)) }

            ctx.fill(disc(r), with: .linearGradient(Gradient(colors: [Color(hex: 0xe9e4d8), Color(hex: 0x6f6a60), Color(hex: 0xd8d2c4)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            ctx.fill(disc(r * 0.84), with: .color(Color(hex: 0x07140b)))

            let shadow = Angle.degrees(6 + (1 - signal) * 115)   // half-width of the dark wedge
            var fan = Path()
            fan.move(to: c)
            fan.addArc(center: c, radius: r * 0.8, startAngle: .degrees(-90) + shadow, endAngle: .degrees(270) - shadow, clockwise: false)
            fan.closeSubpath()
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: .phosphor.opacity(glow * 0.9), radius: r * 0.15))
                layer.fill(fan, with: .radialGradient(Gradient(colors: [.phosphor.opacity(0.25 * glow), .phosphor.opacity(0.95 * glow)]),
                                                     center: c, startRadius: r * 0.2, endRadius: r * 0.8))
            }
            ctx.fill(disc(r * 0.3), with: .radialGradient(Gradient(colors: [Color(hex: 0x3a3a3a), .black]),
                                                          center: CGPoint(x: c.x - r * 0.08, y: c.y - r * 0.08), startRadius: 0, endRadius: r * 0.3))
        }
        .accessibilityElement()
        .accessibilityLabel("Signal")
        .accessibilityValue("\(Int(signal * 100)) percent")
    }
}

/// An ivory piano key. Pressed keys latch down into the case, the way the mechanism did.
struct KeyCap: View {
    var label: String
    var down: Bool
    var size = CGSize(width: 44, height: 60)

    var body: some View {
        let travel = size.height * 0.1
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(bottomLeadingRadius: size.width * 0.14, bottomTrailingRadius: size.width * 0.14)
                .fill(LinearGradient(colors: [.ivory, Color(hex: 0xd9ccaa)], startPoint: .top, endPoint: .bottom))
            Text(label)
                .font(.gill(size.width * 0.24, bold: true))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 3)
                .padding(.bottom, size.height * 0.12)
        }
        .frame(width: size.width, height: size.height - (down ? travel : 0))
        .brightness(down ? -0.07 : 0)
        .shadow(color: .black.opacity(down ? 0.25 : 0.55), radius: down ? 1 : 3, y: down ? 1 : 4)
        .frame(height: size.height, alignment: .top)
    }
}
