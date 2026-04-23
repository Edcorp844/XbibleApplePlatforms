
import Foundation
import XbibleEngine

extension Notification.Name {
    static let installationStateChanged = Notification.Name("installationStateChanged")
}

enum TaskMessage: Equatable {
    case sourcesUpdated([XbibleEngine.ModuleSource])
    case sourcesFailed
    case fetchStarted
    case fetchProgress(progress: Double, status: String, downloadedBytes: Int64, totalBytes: Int64)
    case fetchCompleted([XbibleEngine.SwordModule])
    case fetchFailed
    
    case installStarted(moduleName: String)
    case installProgress(moduleName: String, progress: Double, status: String, downloadedBytes: Int64, totalBytes: Int64)
    case installCompleted(moduleName: String)
    case installFailed(moduleName: String)
    case installCancelled(moduleName: String)
}

