import MapKit

final class RainViewerOverlay: MKTileOverlay {
    var radarPath: String
    var rvLayer: RainViewerService.Layer
    var frameHost: String

    init(path: String, host: String = "https://tilecache.rainviewer.com",
         layer: RainViewerService.Layer = .radar) {
        self.radarPath = path
        self.frameHost = host
        self.rvLayer   = layer
        super.init(urlTemplate: nil)
        tileSize          = CGSize(width: 256, height: 256)
        isGeometryFlipped = true
        minimumZ = 1
        maximumZ = 12   // RainViewer поддерживает до z=12 для радара и спутника
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let frame = RadarFrame(time: .now, path: radarPath, host: frameHost)
        return RainViewerService.tileURL(frame: frame, layer: rvLayer,
                                         z: path.z, x: path.x, y: path.y)
    }

    // Фильтруем 404 → возвращаем nil (прозрачный тайл), а не ошибку.
    // Без этого MapKit рисует "zoom level is not supported" поверх карты.
    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let tileURL = url(forTilePath: path)
        URLSession.shared.dataTask(with: tileURL) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let data, !data.isEmpty {
                result(data, nil)
            } else {
                result(nil, nil)   // прозрачный тайл вместо ошибки
            }
        }.resume()
    }
}

final class RainViewerRenderer: MKTileOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        context.setAlpha(0.65)
        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}
