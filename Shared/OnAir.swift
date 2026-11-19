import Foundation

/// What's on a station right now, from the RMS API that bbc.co.uk/sounds itself reads. No key needed.
struct OnAir: Sendable, Equatable {
    var programme: String
    var detail: String?   // episode title or synopsis
    var track: String?    // "Artist – Title", only while the station marks it as playing now
    var ends: Date

    static func fetch(_ station: Station) async -> OnAir? {
        let api = "https://rms.api.bbc.co.uk/v2"
        async let show: Broadcasts? = get("\(api)/broadcasts/latest?service=\(station.id)&on_air=now")
        async let song: Segments? = get("\(api)/services/\(station.id)/segments/latest?limit=1")
        guard let now = await show?.data.first else { return nil }
        let playing = await song?.data.first.flatMap { $0.offset?.now_playing == true ? $0 : nil }
        return OnAir(
            programme: now.programme.titles.primary,
            detail: now.programme.synopses?.short ?? now.programme.titles.secondary,   // some secondaries are just a date
            track: playing.map { [$0.titles.primary, $0.titles.secondary].compactMap { $0 }.joined(separator: " – ") },
            ends: now.end)
    }

    private static func get<T: Decodable>(_ url: String) async -> T? {
        guard let (data, _) = try? await URLSession.shared.data(from: URL(string: url)!) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }
}

private struct Titles: Decodable { let primary: String; let secondary: String? }

private struct Broadcasts: Decodable {
    struct Broadcast: Decodable { let end: Date; let programme: Programme }
    struct Programme: Decodable { let titles: Titles; let synopses: Synopses? }
    struct Synopses: Decodable { let short: String? }
    let data: [Broadcast]
}

private struct Segments: Decodable {
    struct Segment: Decodable { let titles: Titles; let offset: Offset? }
    struct Offset: Decodable { let now_playing: Bool }
    let data: [Segment]
}
