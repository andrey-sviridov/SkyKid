import SwiftUI
import MapKit

struct RadarMapView: View {
    let coordinate: CLLocationCoordinate2D
    var weather: WeatherData?

    @State private var vm = RadarMapViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header: погода + переключатель слоёв ──────────────────────
            headerBar

            // ── Карта занимает всё оставшееся пространство ────────────────
            ZStack(alignment: .bottom) {
                UnifiedRadarMapView(
                    userCoordinate: coordinate,
                    radarPath: vm.currentFrame?.path,
                    frameHost: vm.currentFrame?.host ?? "https://tilecache.rainviewer.com",
                    rvLayer: vm.activeLayer
                )
                .ignoresSafeArea(edges: .bottom)

                if !vm.frames.isEmpty {
                    playerPanel
                        .padding(.horizontal, 14)
                        .padding(.bottom, 24)
                }

                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(1.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }

                if vm.loadError && !vm.isLoading {
                    Label("Нет данных. Проверьте соединение.", systemImage: "wifi.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 120)
                }
            }
        }
        .task { await vm.loadFrames() }
        // Останавливаем анимацию когда пользователь уходит на другую вкладку.
        // Без этого Task-цикл обновляет состояние каждые 600 мс и мешает
        // автогашению экрана.
        .onDisappear { vm.pause() }
        .navigationTitle("Карта погоды")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Header bar (погода + чипы слоёв)

    private var headerBar: some View {
        VStack(spacing: 0) {
            // Строка погоды
            if let w = weather {
                HStack(spacing: 12) {
                    Image(systemName: w.conditionIcon)
                        .font(.system(size: 30))
                        .symbolRenderingMode(.multicolor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(Int(w.temperature.rounded()))°  \(w.conditionDescription)")
                            .font(.headline)
                        if w.windSpeed > 0.5 {
                            Text("Ветер \(String(format: "%.1f", w.windSpeed)) м/с · \(w.windDirectionLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Ощущаемая температура
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Ощущается")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(w.apparentTemperature.rounded()))°")
                            .font(.title3.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                Divider()
            }

            // Чипы слоёв
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    layerChip(label: "Осадки",  icon: "cloud.rain",  layer: .radar)
                    layerChip(label: "Спутник", icon: "globe",       layer: .satellite)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider()
        }
        .background(Color(.secondarySystemBackground))
    }

    private func layerChip(label: String, icon: String, layer: RainViewerService.Layer) -> some View {
        let active = vm.activeLayer == layer
        return Button {
            Task { await vm.switchLayer(layer) }
        } label: {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(active ? .white : Color.primary.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(active ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color(.tertiarySystemBackground)),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Player panel

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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Native MKMapView with radar overlay

struct UnifiedRadarMapView: UIViewRepresentable {
    let userCoordinate: CLLocationCoordinate2D
    let radarPath: String?
    var frameHost: String
    var rvLayer: RainViewerService.Layer = .radar

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
        let pin = MKPointAnnotation()
        pin.coordinate = userCoordinate
        mv.addAnnotation(pin)
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        context.coordinator.updateRadar(on: mv, path: radarPath, host: frameHost, layer: rvLayer)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var lastPath: String?
        private var lastLayer: RainViewerService.Layer?

        func updateRadar(on mv: MKMapView, path: String?, host: String, layer: RainViewerService.Layer) {
            guard path != lastPath || layer != lastLayer else { return }
            lastPath  = path
            lastLayer = layer
            mv.removeOverlays(mv.overlays)
            if let path {
                mv.addOverlay(RainViewerOverlay(path: path, host: host, layer: layer),
                              level: .aboveRoads)
            }
        }

        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? RainViewerOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            return RainViewerRenderer(tileOverlay: tile)
        }

        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "userDot"
            let view = mv.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.canShowCallout = false
            view.image = Self.dotImage
            return view
        }

        private static let dotImage: UIImage = {
            let size: CGFloat = 18
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            return renderer.image { ctx in
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
