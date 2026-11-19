import Foundation

struct Station: Identifiable, Hashable, Sendable {
    let id: String         // BBC service id
    let name: String       // printed on the dial glass and the keys
    let title: String
    let short: String      // widget key cap
    let frequency: Double  // where it sits on the dial. Real London FM for 1–4; the digital ones get a spot of their own

    static let band = 87.5...108.0

    static let all: [Station] = [
        .init(id: "bbc_radio_two", name: "Radio 2", title: "BBC Radio 2", short: "2", frequency: 89.1),
        .init(id: "bbc_radio_three", name: "Radio 3", title: "BBC Radio 3", short: "3", frequency: 91.3),
        .init(id: "bbc_radio_fourfm", name: "Radio 4", title: "BBC Radio 4", short: "4", frequency: 93.5),
        .init(id: "bbc_radio_one", name: "Radio 1", title: "BBC Radio 1", short: "1", frequency: 98.8),
        .init(id: "bbc_6music", name: "6 Music", title: "BBC 6 Music", short: "6", frequency: 101.4),
        .init(id: "bbc_radio_five_live", name: "5 Live", title: "BBC Radio 5 Live", short: "5", frequency: 103.6),
        .init(id: "bbc_1xtra", name: "1Xtra", title: "BBC 1Xtra", short: "1X", frequency: 105.4),
        .init(id: "bbc_world_service", name: "World", title: "BBC World Service", short: "W", frequency: 107.2),
    ]

    static func named(_ id: String) -> Station? { all.first { $0.id == id } }

    static func nearest(to frequency: Double) -> Station? {
        all.min { abs($0.frequency - frequency) < abs($1.frequency - frequency) }
    }

    var link: URL { URL(string: "wireless://tune/\(id)")! }

    /// The BBC's stable entry point. It's a master playlist that always points at whichever CDN pool
    /// is live today, so the pool rotations that break hardcoded URLs never reach us.
    /// `uk` gives 320 kbps; `nonuk` (96 kbps) is the one that plays abroad.
    func stream(uk: Bool) -> URL {
        URL(string: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/\(uk ? "uk" : "nonuk")/pc_hd_abr_v2/aks/\(id).m3u8")!
    }
}
