import Foundation
import Observation

// MARK: - Weather layer types

enum WeatherMapLayer: String, CaseIterable, Identifiable {
    case radar       = "radar"
    case satellite   = "satellite"
    case wind        = "wind"
    case temperature = "temperature"
    case clouds      = "clouds"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .radar:       return "Осадки"
        case .satellite:   return "Спутник"
        case .wind:        return "Ветер"
        case .temperature: return "Темп."
        case .clouds:      return "Облака"
        }
    }

    var icon: String {
        switch self {
        case .radar:       return "cloud.rain.fill"
        case .satellite:   return "globe"
        case .wind:        return "wind"
        case .temperature: return "thermometer.medium"
        case .clouds:      return "cloud.fill"
        }
    }

    var isAnimated: Bool { self == .radar || self == .satellite }
    var requiresOWMKey: Bool { !isAnimated }

    var owmLayerName: String? {
        switch self {
        case .wind:        return "wind_new"
        case .temperature: return "temp_new"
        case .clouds:      return "clouds_new"
        default:           return nil
        }
    }

    var rvLayer: RainViewerService.Layer? {
        switch self {
        case .radar:     return .radar
        case .satellite: return .satellite
        default:         return nil
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class MapWeatherViewModel {
    var frames:       [RadarFrame]    = []
    var currentIndex: Int             = 0
    var isPlaying:    Bool            = false
    var isLoading:    Bool            = false
    var activeLayer:  WeatherMapLayer = .radar

    private var playTask: Task<Void, Never>?

    var currentFrame: RadarFrame? {
        frames.indices.contains(currentIndex) ? frames[currentIndex] : nil
    }

    var isForecast: Bool {
        (currentFrame?.time ?? Date()) > Date()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var currentTimeLabel: String {
        guard let frame = currentFrame else { return "" }
        return Self.timeFormatter.string(from: frame.time)
    }

    func loadFrames(for layer: WeatherMapLayer) async {
        guard let rvLayer = layer.rvLayer else { return }
        isLoading = true
        do {
            frames = try await RainViewerService.fetchFrames(layer: rvLayer)
            currentIndex = max(0, frames.firstIndex(where: { $0.time >= Date() }) ?? frames.count - 1)
        } catch {
            frames = []
        }
        isLoading = false
    }

    func selectLayer(_ layer: WeatherMapLayer) {
        pause()
        frames = []
        activeLayer = layer
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        isPlaying = true
        playTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { break }
                currentIndex = (currentIndex < frames.count - 1) ? currentIndex + 1 : 0
            }
        }
    }

    func pause() {
        isPlaying = false
        playTask?.cancel()
    }

    func seek(to index: Int) {
        currentIndex = max(0, min(index, frames.count - 1))
    }
}
