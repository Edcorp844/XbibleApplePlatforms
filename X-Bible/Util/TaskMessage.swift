
import Foundation
import XbibleEngine

extension Notification.Name {
    static let installationStateChanged = Notification.Name("installationStateChanged")
}

/// Represents the various messages the StoreTaskManager can send to the UI.
enum TaskMessage {
    case sourcesUpdated([XbibleEngine.ModuleSource])
    case sourcesFailed
    case fetchStarted
    case fetchProgress(progress: Double, status: String, downloadedBytes: Int64, totalBytes: Int64)
    case fetchCompleted(source: String, modules: [XbibleEngine.SwordModule])
    case fetchFailed(source: String)
    case installStarted(moduleName: String)
    case installProgress(moduleName: String, progress: Double, status: String, downloadedBytes: Int64, totalBytes: Int64)
    case installCompleted(moduleName: String)
    case installFailed(moduleName: String)
    case installCancelled(moduleName: String)
}
