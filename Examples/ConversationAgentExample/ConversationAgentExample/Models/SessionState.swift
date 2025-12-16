import Foundation

enum SessionState: Equatable {
    case idle
    case running
    case completed(String)
    case error(String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
