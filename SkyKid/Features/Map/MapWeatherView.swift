import SwiftUI
import MapKit

// MARK: - Main View

struct MapWeatherView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var vm = MapWeatherViewModel()
    @AppStorage("owmApiKey") private var owmApiKey: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            WeatherMapRepresentable(
                userCoordinate: coordinate,
                frames:         vm.frames,
                currentIndex:   vm.currentIndex,
                activeLayer:    vm.activeLayer,
                owmApiKey:      owmApiKey
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                if vm.activeLayer.isAnimated && !vm.frames.isEmpty {
                    MapPlayerPanel(vm: vm)
                        .padding(.horizontal, 16)
                }

                MapLayerChips(
                    activeLayer:     vm.activeLayer,
                    owmKeyAvailable: !owmApiKey.isEmpty,
                    onSelect:        { vm.selectLayer($0) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            if vm.isLoading {
                ProgressView()
                    .padding(14)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .task(id: vm.activeLayer) {
            if vm.activeLayer.isAnimated {
                await vm.loadFrames(for: vm.activeLayer)
            }
        }
        .navigationTitle("Карта погоды")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

// MARK: - Layer chip strip

struct MapLayerChips: View {
    let activeLayer: WeatherMapLayer
    let owmKeyAvailable: Bool
    let onSelect: (WeatherMapLayer) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WeatherMapLayer.allCases) { layer in
                    let isActive = layer == activeLayer
                    let locked   = layer.requiresOWMKey && !owmKeyAvailable
                    chip(layer: layer, isActive: isActive, locked: locked)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func chip(layer: WeatherMapLayer, isActive: Bool, locked: Bool) -> some View {
        Button {
            if !locked { onSelect(layer) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: layer.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(layer.title)
                    .font(.system(size: 13, weight: .semibold))
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .opacity(0.55)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                isActive ? Color.blue : Color.white.opacity(locked ? 0.25 : 0.6),
                in: Capsule()
            )
            .foregroundStyle(isActive ? .white : (locked ? Color(.tertiaryLabel) : .primary))
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }
}

// MARK: - Player panel

struct MapPlayerPanel: View {
    @Bindable var vm: MapWeatherViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: vm.isForecast ? "arrow.triangle.2.circlepath" : "clock")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(vm.currentTimeLabel)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer()
                Text(vm.isForecast ? "прогноз" : "история")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(vm.currentIndex) },
                    set: { vm.seek(to: Int($0)) }
                ),
                in: 0...Double(max(vm.frames.count - 1, 1)),
                step: 1
            )
            .tint(.blue)

            HStack(spacing: 20) {
                Button { vm.seek(to: vm.currentIndex - 1) } label: {
                    Image(systemName: "backward.fill")
                }
                .disabled(vm.currentIndex == 0)

                Button { vm.togglePlay() } label: {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                }

                Button { vm.seek(to: vm.currentIndex + 1) } label: {
                    Image(systemName: "forward.fill")
                }
                .disabled(vm.currentIndex >= vm.frames.count - 1)
            }
            .font(.title2)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - UIViewRepresentable map

struct WeatherMapRepresentable: UIViewRepresentable {
    let userCoordinate: CLLocationCoordinate2D
    let frames:         [RadarFrame]
    let currentIndex:   Int
    let activeLayer:    WeatherMapLayer
    let owmApiKey:      String

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate           = context.coordinator
        mv.showsUserLocation  = false
        mv.mapType            = .standard
        mv.pointOfInterestFilter = .excludingAll
        mv.setRegion(
            MKCoordinateRegion(
                center: userCoordinate,
                span:   MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
            ),
            animated: false
        )
        let pin = MKPointAnnotation()
        pin.coordinate = userCoordinate
        mv.addAnnotation(pin)
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        let c = context.coordinator

        if activeLayer.isAnimated {
            let rvLayer = activeLayer.rvLayer ?? .radar

            // Rebuild overlay pool when layer changes or frames load for the first time
            if c.loadedLayerType != activeLayer || c.loadedFrameCount != frames.count {
                mv.removeOverlays(mv.overlays)
                c.renderers.removeAll()
                c.loadedLayerType    = activeLayer
                c.loadedFrameCount   = frames.count
                c.lastDisplayedIndex = -1

                for (i, frame) in frames.enumerated() {
                    mv.addOverlay(
                        WeatherTileOverlay(frameIndex: i, framePath: frame.path, rvLayer: rvLayer),
                        level: .aboveRoads
                    )
                }
            }

            // Swap alpha — NO overlay add/remove, just renderer opacity
            if c.lastDisplayedIndex != currentIndex {
                c.renderers[c.lastDisplayedIndex]?.alpha = 0
                c.renderers[currentIndex]?.alpha         = 0.6
                c.lastDisplayedIndex = currentIndex
            }

        } else {
            // Static OWM layer — rebuild only when layer changes
            if c.loadedLayerType != activeLayer {
                mv.removeOverlays(mv.overlays)
                c.renderers.removeAll()
                c.loadedLayerType    = activeLayer
                c.loadedFrameCount   = 0
                c.lastDisplayedIndex = -1

                if let name = activeLayer.owmLayerName, !owmApiKey.isEmpty {
                    mv.addOverlay(
                        OWMTileOverlay(owmLayer: name, apiKey: owmApiKey),
                        level: .aboveRoads
                    )
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var renderers:          [Int: MKTileOverlayRenderer] = [:]
        var loadedFrameCount:   Int            = 0
        var loadedLayerType:    WeatherMapLayer = .radar
        var lastDisplayedIndex: Int            = -1

        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? WeatherTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: tile)
                r.alpha = 0  // hidden until updateUIView sets the active frame
                renderers[tile.frameIndex] = r
                return r
            }
            if let owm = overlay as? OWMTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: owm)
                r.alpha = 0.75
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id   = "userDot"
            let view = mv.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation  = annotation
            view.canShowCallout = false
            view.image       = Self.dotImage
            return view
        }

        private static let dotImage: UIImage = {
            let size: CGFloat = 18
            return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
                let rect = CGRect(x: 2, y: 2, width: size - 4, height: size - 4)
                ctx.cgContext.setShadow(offset: .zero, blur: 3,
                    color: UIColor.black.withAlphaComponent(0.3).cgColor)
                UIColor.systemBlue.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                ctx.cgContext.setShadow(offset: .zero, blur: 0)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(2)
                ctx.cgContext.strokeEllipse(in: rect)
            }
        }()
    }
}
