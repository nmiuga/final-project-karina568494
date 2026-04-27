import Foundation
import Combine

@MainActor
final class ReadingTimerViewModel: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRunning: Bool = false

    private var timer: Timer?
    private var startDate: Date?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startDate = Date()
        // Schedule the timer on the main run loop and forward ticks to a @MainActor method
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerFired(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        stop()
        elapsed = 0
        startDate = nil
    }

    @objc
    private func timerFired(_ timer: Timer) {
        // This method runs on the main run loop; accessing main-actor state is safe here
        if let start = startDate {
            elapsed = Date().timeIntervalSince(start)
        }
    }
}
