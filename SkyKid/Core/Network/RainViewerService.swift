import Foundation

struct RainViewerService {
    enum Layer { case radar, satellite }

    static func fetchFrames(layer: Layer = .radar) async throws -> [RadarFrame] {
        let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONDecoder().decode(RVRoot.self, from: data)

        switch layer {
        case .radar:
            let past     = root.radar.past.map     { RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path) }
            let nowcast  = root.radar.nowcast.map  { RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path) }
            return (past + nowcast).sorted { $0.time < $1.time }
        case .satellite:
            let infrared = (root.satellite?.infrared ?? []).map {
                RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path)
            }
            return infrared.sorted { $0.time < $1.time }
        }
    }

    static func tileURL(path: String, layer: Layer, z: Int, x: Int, y: Int) -> URL {
        let suffix: String
        switch layer {
        case .radar:     suffix = "/2/1_1.png"
        case .satellite: suffix = "/0/0_0.png"
        }
        return URL(string: "https://tilecache.rainviewer.com\(path)/256/\(z)/\(x)/\(y)\(suffix)")!
    }
}

private struct RVRoot: Decodable {
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
