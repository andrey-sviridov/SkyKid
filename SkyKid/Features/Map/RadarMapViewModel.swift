import Foundation
import Observation

@MainActor
@Observable
final class RadarMapViewModel {
    var frames: [RadarFrame] = []
    var currentIndex: Int = 0
    var isPlaying = false
    var isLoading = false

    private var playTask: Task<Void, Never>?

    var currentFrame: RadarFrame? {
        frames.indices.contains(currentIndex) ? frames[currentIndex] : nil
    }

    var currentTimeLabel: String {
        guard let frame = currentFrame else { return "" }
        return Self.timeFormatter.string(from: frame.time)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    func loadFrames() async {
        isLoading = true
        do {
            frames = try await RainViewerService.fetchFrames()
            // Start on most recent past frame
            currentIndex = max(0, frames.firstIndex(where: { $0.time >= Date() }) ?? frames.count - 1)
        } catch {
            frames = []
        }
        isLoading = false
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        isPlaying = true
        playTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { break }
                if currentIndex < frames.count - 1 {
                    currentIndex += 1
                } else {
                    currentIndex = 0
                }
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
