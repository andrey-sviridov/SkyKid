import MapKit

final class RainViewerOverlay: MKTileOverlay {
    var radarPath: String

    init(path: String) {
        self.radarPath = path
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: 256, height: 256)
        self.isGeometryFlipped = true
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        RainViewerService.tileURL(path: radarPath, layer: .radar, z: path.z, x: path.x, y: path.y)
    }
}

final class RainViewerRenderer: MKTileOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        context.setAlpha(0.6)
        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}
