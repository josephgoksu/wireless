import SwiftUI

struct RadioView: View {
    private var radio: Radio { .shared }

    var body: some View {
        VStack(spacing: 18) {
            DialGlass(frequency: radio.frequency, glow: radio.glow, tuned: radio.tuned)
                .frame(height: 104)

            HStack(spacing: 18) {
                Grille(glow: radio.glow)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        MagicEye(signal: radio.signal, glow: radio.glow)
                            .frame(width: 58, height: 58)
                            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                        VStack(alignment: .leading, spacing: 5) {
                            Engraving("SIGNAL")
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(radio.receiving ? Color(hex: 0xff4a2e) : Color(hex: 0x3a1a12))
                                    .shadow(color: .red.opacity(radio.receiving ? 0.9 : 0), radius: 4)
                                    .frame(width: 8, height: 8)
                                Engraving("ON AIR")
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    StationCard(radio: radio)
                }
                .frame(width: 214)
            }
            .frame(height: 176)

            HStack(spacing: 22) {
                Knob(label: "VOLUME", angle: .degrees(-135 + radio.volume * 270)) {
                    radio.volume = min(1, max(0, radio.volume + $0 * 0.004))
                }
                HStack(spacing: 5) {
                    Button { radio.power(false) } label: { KeyCap(label: "OFF", down: !radio.isOn) }
                    ForEach(Station.all) { s in
                        Button { radio.press(s) } label: { KeyCap(label: s.name, down: radio.isOn && radio.latched == s) }
                            .accessibilityLabel(s.title)
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(duration: 0.18), value: radio.latched)
                .animation(.spring(duration: 0.18), value: radio.isOn)
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.walnutDark.opacity(0.85)).shadow(color: .black, radius: 2))
                Knob(label: "TUNING", angle: .degrees(radio.frequency * 47)) {
                    radio.tune(by: $0 * 0.025)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(width: 740)
        .background(Cabinet().gesture(WindowDragGesture()))
        .padding(30)   // room for the cabinet's shadow on the desk
        .containerBackground(.clear, for: .window)
    }
}

private struct Cabinet: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        Walnut()
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.55)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 3))
            .overlay(shape.inset(by: 9).stroke(Color.black.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 14)
    }
}

/// Speaker cloth, lit from behind by the valves, with the maker's script badge.
private struct Grille: View {
    var glow: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack {
            Color(hex: 0x6b5236)
            RadialGradient(colors: [Color(hex: 0xff9a3c).opacity(0.55 * glow), .clear], center: .init(x: 0.5, y: 0.75),
                           startRadius: 0, endRadius: 260)
            Canvas { ctx, size in   // the weave
                var warp = Path(), weft = Path()
                for y in stride(from: 0, to: size.height, by: 3) { warp.addRect(CGRect(x: 0, y: y, width: size.width, height: 1.3)) }
                for x in stride(from: 0, to: size.width, by: 3) { weft.addRect(CGRect(x: x, y: 0, width: 1.3, height: size.height)) }
                ctx.fill(warp, with: .color(.black.opacity(0.28)))
                ctx.fill(weft, with: .color(Color(hex: 0xe8c99a).opacity(0.1)))
            }
            VStack(spacing: 22) {
                ForEach(0..<5, id: \.self) { _ in
                    Capsule().fill(LinearGradient.brass).frame(height: 3).shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                }
            }
            .padding(.horizontal, 22)
            Text("Wireless")
                .font(.custom("SnellRoundhand-Black", size: 46))
                .foregroundStyle(LinearGradient.brass)
                .shadow(color: .black.opacity(0.7), radius: 1.5, y: 2)
                .padding(.horizontal, 18)
                .background(Capsule().fill(Color(hex: 0x3a2a1a)).shadow(color: .black.opacity(0.6), radius: 3, y: 2))
        }
        .clipShape(shape)
        .overlay(shape.stroke(LinearGradient(colors: [.black.opacity(0.6), .white.opacity(0.15)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
        .accessibilityHidden(true)
    }
}

/// The programme card tucked into the set, typed up from the BBC schedule.
private struct StationCard: View {
    let radio: Radio

    var body: some View {
        let station = radio.tuned
        let (header, title, detail): (String, String, String) =
            if !radio.isOn { ("OFF AIR", "Good evening.", "Press a station key, or turn the tuning knob and listen for the whistle.") }
            else if let station, let onAir = radio.onAir {
                ("NOW ON \(station.title.dropFirst(4).uppercased())", onAir.programme, onAir.track.map { "♪ \($0)" } ?? onAir.detail ?? "")
            } else if let station { ("\(station.name.uppercased())", radio.receiving ? station.title : "Tuning in…", radio.receiving ? "" : "The valves are finding the signal.") }
            else { ("BETWEEN STATIONS", "· · ·", "Nothing but the ether here.") }

        VStack(alignment: .leading, spacing: 4) {
            Text(header).font(.gill(10, bold: true)).tracking(1.6).foregroundStyle(Color.needle)
            Text(title).font(.typewriter(15, bold: true)).lineLimit(2)
            Text(detail).font(.typewriter(11)).lineLimit(3).opacity(0.75)
        }
        .foregroundStyle(Color.ink)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient(colors: [.paper, Color(hex: 0xe2d1a6)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.45), radius: 3, x: 1, y: 3)
        .rotationEffect(.degrees(-1.2))
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.4), value: title)
        .accessibilityElement(children: .combine)
    }
}

/// Bakelite knob with a knurled rim. Drag up/right to turn it clockwise.
private struct Knob: View {
    let label: String
    let angle: Angle
    let turn: (Double) -> Void
    @State private var last = CGSize.zero

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().fill(Color(hex: 0x170c05))
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x6a4428), Color(hex: 0x2c170a), Color(hex: 0x120803)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 44))
                    .padding(5)
                Group {   // only the knurling and pointer turn; the light stays where the lamp is
                    ForEach(0..<40, id: \.self) { i in
                        Capsule().fill(Color.white.opacity(0.08)).frame(width: 2, height: 6)
                            .offset(y: -33).rotationEffect(.degrees(Double(i) * 9))
                    }
                    Capsule().fill(Color.ivory).frame(width: 4, height: 13).offset(y: -21)
                }
                .rotationEffect(angle)
                Circle().fill(LinearGradient.brass).frame(width: 20, height: 20).shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            }
            .frame(width: 72, height: 72)
            .shadow(color: .black.opacity(0.6), radius: 5, y: 5)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    turn((v.translation.width - last.width) - (v.translation.height - last.height))
                    last = v.translation
                }
                .onEnded { _ in last = .zero })
            Engraving(label)
        }
        .accessibilityElement()
        .accessibilityLabel(label.capitalized)
        .accessibilityAdjustableAction { turn($0 == .increment ? 4 : -4) }
    }
}

private struct Engraving: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.gill(10, bold: true)).tracking(2.2)
            .foregroundStyle(LinearGradient.brass)
            .shadow(color: .black.opacity(0.8), radius: 0.5, y: 1)
    }
}
