import SwiftUI
import MapKit

struct RadarMapView: View {
    @State private var vm = RadarMapViewModel()
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        ZStack(alignment: .bottom) {
            // Единый MKMapView — карта + радарный слой в одном UIView
            UnifiedRadarMapView(
                userCoordinate: coordinate,
                radarPath: vm.currentFrame?.path
            )
            .ignoresSafeArea(edges: .top)

            if !vm.frames.isEmpty {
                playerPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }

            if vm.isLoading {
                ProgressView()
                    .scaleEffect(1.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .task { await vm.loadFrames() }
        .navigationTitle("Осадки")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playerPanel: some View {
        VStack(spacing: 10) {
            HStack {
                let isForecast = (vm.currentFrame?.time ?? Date()) > Date()
                Image(systemName: isForecast ? "arrow.triangle.2.circlepath" : "clock")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(vm.currentTimeLabel)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer()
                Text(isForecast ? "прогноз" : "история")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { Double(vm.currentIndex) },
                set: { vm.seek(to: Int($0)) }
            ), in: 0...Double(max(vm.frames.count - 1, 1)), step: 1)
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
                .disabled(vm.currentIndex == vm.frames.count - 1)
            }
            .font(.title2)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Единая карта с радарным слоем (один MKMapView)

struct UnifiedRadarMapView: UIViewRepresentable {
    let userCoordinate: CLLocationCoordinate2D
    let radarPath: String?

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.showsUserLocation = false
        mv.mapType = .standard
        mv.pointOfInterestFilter = .excludingAll

        mv.setRegion(
            MKCoordinateRegion(
                center: userCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
            ),
            animated: false
        )

        // Метка текущего местоположения
        let pin = MKPointAnnotation()
        pin.coordinate = userCoordinate
        mv.addAnnotation(pin)

        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        context.coordinator.updateRadar(on: mv, path: radarPath)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var lastPath: String?

        func updateRadar(on mv: MKMapView, path: String?) {
            guard path != lastPath else { return }
            lastPath = path
            mv.removeOverlays(mv.overlays)
            if let path {
                mv.addOverlay(RainViewerOverlay(path: path), level: .aboveRoads)
            }
        }

        // Рендер радарного тайла
        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? RainViewerOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            return RainViewerRenderer(tileOverlay: tile)
        }

        // Синяя точка местоположения
        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "userDot"
            let view = mv.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.canShowCallout = false
            view.image = Self.dotImage
            view.centerOffset = .zero
            return view
        }

        // Кэшируем изображение точки
        private static let dotImage: UIImage = {
            let size: CGFloat = 18
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            return renderer.image { ctx in
                let rect = CGRect(x: 2, y: 2, width: size - 4, height: size - 4)
                // Тень
                ctx.cgContext.setShadow(offset: .zero, blur: 3, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                // Синий круг
                UIColor.systemBlue.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                ctx.cgContext.setShadow(offset: .zero, blur: 0)
                // Белый ободок
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(2)
                ctx.cgContext.strokeEllipse(in: rect)
            }
        }()
    }
}
