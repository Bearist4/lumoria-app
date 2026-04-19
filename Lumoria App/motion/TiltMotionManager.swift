import Foundation
import CoreMotion
import Combine
import UIKit

/// Singleton publisher of device attitude used by all tilt-driven views.
///
/// - One `CMMotionManager` app-wide.
/// - Auto-starts on `.active` scene phase, stops on `.background`.
/// - Throttles 60 → 20 Hz when `ProcessInfo.isLowPowerModeEnabled` is on.
/// - Zeroes output when `UIAccessibility.isReduceMotionEnabled` is on.
@MainActor
final class TiltMotionManager: ObservableObject {

    static let shared = TiltMotionManager()

    /// Roll in radians, clamped to [-π/3, π/3]. 0 = phone flat on face.
    @Published private(set) var roll: Double = 0
    /// Pitch in radians, clamped to [-π/3, π/3].
    @Published private(set) var pitch: Double = 0

    private let manager = CMMotionManager()
    private let clampRange: ClosedRange<Double> = -(.pi / 3)...(.pi / 3)
    private var observers: [NSObjectProtocol] = []

    private init() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.applyUpdateInterval() }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    if UIAccessibility.isReduceMotionEnabled {
                        self?.roll = 0
                        self?.pitch = 0
                    }
                }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive else { return }
        applyUpdateInterval()
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            guard !UIAccessibility.isReduceMotionEnabled else {
                self.roll = 0
                self.pitch = 0
                return
            }
            self.roll = attitude.roll.clamped(to: self.clampRange)
            self.pitch = attitude.pitch.clamped(to: self.clampRange)
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    private func applyUpdateInterval() {
        manager.deviceMotionUpdateInterval = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? 1.0 / 20.0
            : 1.0 / 60.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
