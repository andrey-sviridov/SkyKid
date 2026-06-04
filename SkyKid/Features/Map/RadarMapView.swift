import SwiftUI
import MapKit

struct RadarMapView: View {
    @State private var vm = RadarMapViewModel()
    let coordinate: CLLocationCoordinate2D

    @State private var cameraPosition: MapCameraPosition

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3))
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

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

    @ViewBuilder
    private var mapLayer: some View {
        if let frame = vm.currentFrame {
            Map(position: $cameraPosition) {
                Annotation("", coordinate: coordinate) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            .overlay(RadarTileView(frame: frame))
            .ignoresSafeArea(edges: .top)
        } else {
            Map(position: $cameraPosition)
                .ignoresSafeArea(edges: .top)
        }
    }

    private var playerPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: vm.currentFrame?.time ?? Date() > Date() ? "arrow.triangle.2.circlepath" : "clock")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(vm.currentTimeLabel)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer()
                Text(vm.currentFrame.map { $0.time > Date() ? "прогноз" : "история" } ?? "")
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

// UIKit bridge to draw MKTileOverlay on top of SwiftUI Map
struct RadarTileView: UIViewRepresentable {
    let frame: RadarFrame

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.isUserInteractionEnabled = false
        mv.backgroundColor = .clear
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        mv.removeOverlays(mv.overlays)
        let overlay = RainViewerOverlay(path: frame.path)
        mv.addOverlay(overlay, level: .aboveRoads)
        mv.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? RainViewerOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            return RainViewerRenderer(tileOverlay: tile)
        }
    }
}
