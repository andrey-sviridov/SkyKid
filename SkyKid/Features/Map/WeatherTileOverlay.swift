import MapKit

// MARK: - Shared tile cache

private final class TileCache: @unchecked Sendable {
    static let shared = TileCache()
    private let cache = NSCache<NSString, NSData>()
    private init() { cache.countLimit = 600 }

    func get(_ key: String) -> Data? {
        cache.object(forKey: key as NSString) as Data?
    }
    func set(_ key: String, data: Data) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }
}

// MARK: - RainViewer animated tile (one per frame)

final class WeatherTileOverlay: MKTileOverlay {
    let frameIndex: Int
    private let framePath: String
    private let rvLayer: RainViewerService.Layer

    init(frameIndex: Int, framePath: String, rvLayer: RainViewerService.Layer) {
        self.frameIndex = frameIndex
        self.framePath  = framePath
        self.rvLayer    = rvLayer
        super.init(urlTemplate: nil)
        tileSize           = CGSize(width: 256, height: 256)
        isGeometryFlipped  = true
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        RainViewerService.tileURL(path: framePath, layer: rvLayer, z: path.z, x: path.x, y: path.y)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let key = "\(rvLayer)_\(framePath)_\(path.z)_\(path.x)_\(path.y)"
        if let cached = TileCache.shared.get(key) {
            result(cached, nil)
            return
        }
        URLSession.shared.dataTask(with: url(forTilePath: path)) { data, _, error in
            if let data { TileCache.shared.set(key, data: data) }
            result(data, error)
        }.resume()
    }
}

// MARK: - OpenWeatherMap static tile

final class OWMTileOverlay: MKTileOverlay {
    private let owmLayer: String
    private let apiKey: String

    init(owmLayer: String, apiKey: String) {
        self.owmLayer = owmLayer
        self.apiKey   = apiKey
        super.init(urlTemplate: nil)
        tileSize          = CGSize(width: 256, height: 256)
        isGeometryFlipped = false
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        URL(string: "https://tile.openweathermap.org/map/\(owmLayer)/\(path.z)/\(path.x)/\(path.y).png?appid=\(apiKey)")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let key = "owm_\(owmLayer)_\(path.z)_\(path.x)_\(path.y)"
        if let cached = TileCache.shared.get(key) {
            result(cached, nil)
            return
        }
        URLSession.shared.dataTask(with: url(forTilePath: path)) { data, _, error in
            if let data { TileCache.shared.set(key, data: data) }
            result(data, error)
        }.resume()
    }
}
