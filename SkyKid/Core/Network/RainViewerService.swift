import Foundation

struct RainViewerService {
    enum Layer { case radar, satellite }

    // Color scheme 2 = TITAN — стандартная цветовая схема RainViewer (синий→зелёный→жёлтый→красный).
    // Коды: 0=Original, 1=Universal Blue, 2=TITAN, 3=TWC, 4=Meteored, 5=NEXRAD, 6=RAINBOW, 7=Dark Sky
    private static let radarColorScheme = "2"

    static func fetchFrames(layer: Layer = .radar) async throws -> [RadarFrame] {
        let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONDecoder().decode(RVRoot.self, from: data)

        // host берём из ответа API — не хардкодить
        let host = root.host

        switch layer {
        case .radar:
            let past    = root.radar.past.map    { RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path, host: host) }
            let nowcast = root.radar.nowcast.map { RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path, host: host) }
            return (past + nowcast).sorted { $0.time < $1.time }
        case .satellite:
            let infrared = (root.satellite?.infrared ?? []).map {
                RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path, host: host)
            }
            return infrared.sorted { $0.time < $1.time }
        }
    }

    static func tileURL(frame: RadarFrame, layer: Layer, z: Int, x: Int, y: Int) -> URL {
        let suffix: String
        switch layer {
        case .radar:     suffix = "/\(radarColorScheme)/1_1.png"  // smooth=1, snow=1
        case .satellite: suffix = "/0/0_0.png"
        }
        return URL(string: "\(frame.host)\(frame.path)/256/\(z)/\(x)/\(y)\(suffix)")!
    }
}

private struct RVRoot: Decodable {
    let host:      String
    let radar:     RVRadar
    let satellite: RVSatellite?
}

private struct RVRadar: Decodable {
    let past:    [RVFrame]
    let nowcast: [RVFrame]
}

private struct RVSatellite: Decodable {
    let infrared: [RVFrame]
}

private struct RVFrame: Decodable {
    let time: Int
    let path: String
}
