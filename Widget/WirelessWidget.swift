import AppIntents
import SwiftUI
import WidgetKit

@main
struct WirelessWidgets: WidgetBundle {
    var body: some Widget { WirelessWidget() }
}

struct WirelessWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Wireless", intent: PickStation.self, provider: Listings()) { entry in
            WidgetFace(entry: entry)
                .containerBackground(for: .widget) { Walnut() }
        }
        .configurationDisplayName("Wireless")
        .description("A valve wireless for your desktop. Click to tune in.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Configuration

enum StationChoice: String, AppEnum {
    case two = "bbc_radio_two", three = "bbc_radio_three", four = "bbc_radio_fourfm", one = "bbc_radio_one"
    case six = "bbc_6music", five = "bbc_radio_five_live", xtra = "bbc_1xtra", world = "bbc_world_service"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Station"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .two: "Radio 2", .three: "Radio 3", .four: "Radio 4", .one: "Radio 1",
        .six: "6 Music", .five: "5 Live", .xtra: "1Xtra", .world: "World Service",
    ]
    var station: Station { Station.named(rawValue)! }
}

struct PickStation: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Station"
    static let description = IntentDescription("The station the wireless is tuned to.")
    @Parameter(title: "Station", default: .four) var station: StationChoice
}

// MARK: Timeline: one entry per programme, refreshed when it ends

struct Listing: TimelineEntry {
    let date: Date
    let station: Station
    let onAir: OnAir?
}

struct Listings: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Listing {
        Listing(date: .now, station: StationChoice.four.station,
                onAir: OnAir(programme: "The Archers", detail: "An everyday story of country folk", ends: .now))
    }

    func snapshot(for config: PickStation, in context: Context) async -> Listing {
        context.isPreview ? placeholder(in: context) : await listing(config)
    }

    func timeline(for config: PickStation, in context: Context) async -> Timeline<Listing> {
        let entry = await listing(config)
        let next = min(max(entry.onAir?.ends ?? .distantPast, .now + 120), .now + 3600)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func listing(_ config: PickStation) async -> Listing {
        Listing(date: .now, station: config.station.station, onAir: await OnAir.fetch(config.station.station))
    }
}

// MARK: Faces

struct WidgetFace: View {
    let entry: Listing
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.station
        VStack(alignment: .leading, spacing: 8) {
            DialGlass(frequency: s.frequency, glow: 1, tuned: s, names: family == .systemMedium)
                .frame(height: family == .systemMedium ? 46 : 40)

            HStack(alignment: .top, spacing: 8) {
                MagicEye(signal: 1, glow: 1).frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title.uppercased()).font(.gill(9, bold: true)).tracking(1.2).foregroundStyle(LinearGradient.brass)
                    Text(entry.onAir?.programme ?? "Tune in").font(.typewriter(13, bold: true)).lineLimit(2)
                        .foregroundStyle(Color.ivory)
                    if let detail = entry.onAir?.detail {
                        Text(detail).font(.typewriter(10)).lineLimit(family == .systemMedium ? 1 : 3)
                            .foregroundStyle(Color.ivory.opacity(0.7))
                    }
                }
            }

            Spacer(minLength: 0)

            if family == .systemMedium {
                HStack(spacing: 4) {   // preset keys: each one tunes the set straight to its station
                    ForEach(Station.all) { station in
                        Link(destination: station.link) {
                            KeyCap(label: station.short, down: station == s, size: CGSize(width: 34, height: 26))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .widgetURL(s.link)
    }
}
