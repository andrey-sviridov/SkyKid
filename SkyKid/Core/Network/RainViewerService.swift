import Foundation

struct RainViewerService {
    static func fetchFrames() async throws -> [RadarFrame] {
        let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONDecoder().decode(RVRoot.self, from: data)

        let pastFrames = root.radar.past.map {
            RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path)
        }
        let nowcastFrames = root.radar.nowcast.map {
            RadarFrame(time: Date(timeIntervalSince1970: TimeInterval($0.time)), path: $0.path)
        }
        return (pastFrames + nowcastFrames).sorted { $0.time < $1.time }
    }

    static func tileURL(path: String, z: Int, x: Int, y: Int) -> URL {
        URL(string: "https://tilecache.rainviewer.com\(path)/256/\(z)/\(x)/\(y)/2/1_1.png")!
    }
}

// MARK: - Response models

private struct RVRoot: Decodable {
    let radar: RVRadar
}

private struct RVRadar: Decodable {
    let past: [RVFrame]
    let nowcast: [RVFrame]
}

private struct RVFrame: Decodable {
    let time: Int
    let path: String
}
