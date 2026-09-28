import Foundation
import XbibleEngine
import Combine
import SwiftData
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Pipeline Step

enum EngineStep: Equatable {
    case initializing
    case fetchingSource(name: String)
    case processingSelection
    case installingModules
    case failed(String)
    case finished
}

// MARK: - Install Tracker

struct InstallTracker: Identifiable {
    let id = UUID()
    let moduleName: String
    var progress: Float
    var status: String
}

// MARK: - Live Activity Attributes

#if canImport(ActivityKit)
/// Shared between the app target and the widget extension target.
/// If Xcode reports "cannot find type ModuleDownloadAttributes" in the
/// widget extension, verify this file (or a copy of this struct) is a
/// member of BOTH targets.
struct ModuleDownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double         // 0.0 … 1.0
        var status: String           // "Preparing", "Downloading", "Done", …
        var downloadedBytes: Int64
        var totalBytes: Int64
    }
    var moduleName: String
    var sourceName: String
}
#endif

// MARK: - Store Task Manager

class StoreTaskManager: ObservableObject {
    @Published var currentStep: EngineStep = .initializing
    @Published var installers: [InstallTracker] = []
    @Published var globalProgress: Float = 0.0

    let messages = PassthroughSubject<TaskMessage, Never>()

    // 📂 CHANNEL 1: Low-priority background sync lane
    private var catalogSyncQueue = DispatchQueue(label: "com.xbible.catalog-sync-queue", qos: .background)

    // ⚡️ CHANNEL 2: Ultra-high-priority execution lane for instant user feedback
    private var userInteractionQueue = DispatchQueue(label: "com.xbible.user-interaction-queue", qos: .userInteractive)

    private var modelContext: ModelContext?
    private var engine: XBibleEngine?

    private var activeInstallTasks: [String: String] = [:] // [ModuleName: TaskId]
    private let activeTasksLock = NSRecursiveLock()

    // Generation token so switching sources rapidly cancels stale fetches.
    private var fetchGeneration: Int = 0
    private let generationLock = NSLock()

    // MARK: - Live Activity Tracking

    #if canImport(ActivityKit)
    /// One Live Activity per module install. Keyed by moduleName.
    /// Only touched from the main thread — read/write inside
    /// `DispatchQueue.main.async` blocks, or via the helpers below.
    private var activeLiveActivities: [String: Activity<ModuleDownloadAttributes>] = [:]
    #endif

    // MARK: - Setup

    func setup(modelContext: ModelContext, engine: XBibleEngine, queue: DispatchQueue? = nil) {
        self.modelContext = modelContext
        self.engine = engine

        // On first open, only fetch the list of sources — not every catalog.
        startSynchronizationPipelineForSourceListOnly()
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  CHANNEL 1: CATALOG SYNCHRONIZATION (Low Priority Background Execution)
    // ─────────────────────────────────────────────────────────────────────────

    /// Fetch only the catalog for a single, user-selected source.
    func startSynchronizationPipeline(for source: ModuleSource) {
        guard let engine = self.engine else {
            print("❌ [StoreTaskManager] engine is nil – cannot fetch")
            return
        }

        // Bump the generation so any in-flight fetch for a previous source
        // discards its results when it returns.
        generationLock.lock()
        fetchGeneration += 1
        let generation = fetchGeneration
        generationLock.unlock()

        catalogSyncQueue.async { [weak self] in
            guard let self = self else { return }

            let sourceIdentifier = source.name

            self.updateStep(.fetchingSource(name: sourceIdentifier))
            DispatchQueue.main.async { self.globalProgress = 0.0 }

            print("📡 [Fetch] Starting catalog sync")
            print("   source     : \(sourceIdentifier)")
            print("   generation : \(generation)")
            print("   thread     : \(Thread.current)")
            #if os(iOS)
            print("   platform   : iOS")
            #elseif os(macOS)
            print("   platform   : macOS")
            #endif

            let start = CFAbsoluteTimeGetCurrent()

            // ── actual call ──────────────────────────────────────────────
            let modules = engine.fetchRemoteModules(sourceName: sourceIdentifier)
            // ─────────────────────────────────────────────────────────────

            let elapsed = CFAbsoluteTimeGetCurrent() - start

            print("📡 [Fetch] Returned")
            print("   source     : \(sourceIdentifier)")
            print("   count      : \(modules.count)")
            print("   elapsed    : \(String(format: "%.2f", elapsed))s")

            if modules.isEmpty {
                print("❌ [Fetch] EMPTY result for \"\(sourceIdentifier)\"")
                print("   → On iOS this is often App Transport Security,")
                print("     a blocked cleartext HTTP request, or a TLS failure.")
                print("   → Check Xcode console / Console.app for:")
                print("     \"App Transport Security has blocked a cleartext HTTP resource\"")
                print("     or CFNetwork / NSURLError messages.")
            } else {
                print("✅ [Fetch] Got \(modules.count) modules for \"\(sourceIdentifier)\"")
                let preview = modules.prefix(5).map(\.name).joined(separator: ", ")
                print("   preview    : \(preview)\(modules.count > 5 ? "…" : "")")
            }

            // Bail if the user has since switched to a different source.
            self.generationLock.lock()
            let stillCurrent = (generation == self.fetchGeneration)
            self.generationLock.unlock()

            guard stillCurrent else {
                print("↩️ [Fetch] Discarding stale fetch for \(sourceIdentifier) (gen \(generation))")
                return
            }

            DispatchQueue.main.async {
                if modules.isEmpty {
                    self.messages.send(.fetchFailed(source: sourceIdentifier))
                    self.updateStep(.failed("No modules returned for \(sourceIdentifier)."))
                } else {
                    self.messages.send(.fetchCompleted(source: sourceIdentifier, modules: modules))
                    self.globalProgress = 1.0
                    self.updateStep(.finished)
                }
            }
        }
    }

    /// Fetch just the list of available sources — no module catalogs.
    /// Used on first open when no source has been selected yet.
    func startSynchronizationPipelineForSourceListOnly() {
        guard let engine = self.engine else {
            print("❌ [StoreTaskManager] engine is nil – cannot load sources")
            return
        }

        catalogSyncQueue.async { [weak self] in
            guard let self = self else { return }

            self.updateStep(.initializing)
            print("📡 [Sources] Fetching remote source list…")

            let start = CFAbsoluteTimeGetCurrent()
            let sources = engine.getRemoteSourcesWithDetails()
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            print("📡 [Sources] Returned \(sources.count) sources in \(String(format: "%.2f", elapsed))s")

            if sources.isEmpty {
                print("❌ [Sources] Empty list – check engine configuration / network")
                self.updateStep(.failed("No remote sources configured."))
                return
            }

            for s in sources.prefix(10) {
                print("   • \(s.name)")
            }
            if sources.count > 10 {
                print("   … +\(sources.count - 10) more")
            }

            DispatchQueue.main.async {
                self.messages.send(.sourcesUpdated(sources))
                self.updateStep(.finished)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  CHANNEL 2: TARGET ACTIONS (High Priority Interaction Lane)
    // ─────────────────────────────────────────────────────────────────────────

    func installModule(engine: XBibleEngine, source: String, moduleName: String, skipDatabase: Bool = false) {
        userInteractionQueue.async { [weak self] in
            guard let self = self else { return }

            // ── Already installed: bail ─────────────────────────────────
            if engine.isModuleInstalled(moduleName: moduleName) {
                print("ℹ️ [Install] \(moduleName) already installed – skipping")
                DispatchQueue.main.async {
                    if !skipDatabase { self.removePendingInstallation(moduleName: moduleName) }
                    self.messages.send(.installCompleted(moduleName: moduleName))
                }
                return
            }

            // ── Register install + start Live Activity on main thread ───
            DispatchQueue.main.async {
                if !skipDatabase {
                    self.modelContext?.insert(PendingInstallation(moduleName: moduleName, source: source))
                    try? self.modelContext?.save()
                }
                self.messages.send(.installStarted(moduleName: moduleName))

                self.startLiveActivity(moduleName: moduleName, sourceName: source)
            }

            // ⏳ If the catalog for this same source is still being fetched,
            // wait for it to finish before kicking off the install.
            if case .fetchingSource(let activeSource) = self.currentStep, activeSource == source {
                print("⏳ [Install] Source \(source) is still syncing – postponing \(moduleName)…")
                var retryCount = 0
                while case .fetchingSource(let activeSource) = self.currentStep,
                      activeSource == source,
                      retryCount < 20 {
                    Thread.sleep(forTimeInterval: 0.2)
                    retryCount += 1
                }
            }

            print("🔧 [Install] Refreshing installed-modules context for \(moduleName)…")
            _ = engine.refreshInstalledModules()

            print("⬇️ [Install] Starting async install: \(moduleName) (source: \(source))")
            let taskId = engine.installModuleAsync(source: source, moduleName: moduleName)

            self.activeTasksLock.lock()
            self.activeInstallTasks[moduleName] = taskId
            self.activeTasksLock.unlock()

            // ── Progress loop: update Live Activity on every tick ───────
            var lastReportedProgress: Float = -1
            while let status = engine.getTaskStatus(taskId: taskId), status.state == .running {
                let progressValue = status.progress

                // Throttle Live Activity updates to visible deltas so the
                // widget extension doesn't get hammered 20×/second.
                let shouldEmit = lastReportedProgress < 0
                || abs(progressValue - Double(lastReportedProgress)) >= 0.005
                if shouldEmit {
                    lastReportedProgress = Float(progressValue)

                    DispatchQueue.main.async {
                        self.messages.send(.installProgress(
                            moduleName: moduleName,
                            progress: progressValue,
                            status: "Downloading",
                            downloadedBytes: 0,
                            totalBytes: 0
                        ))

                        self.updateLiveActivity(
                            moduleName: moduleName,
                            progress: Double(progressValue),
                            status: "Downloading",
                            downloadedBytes: 0,
                            totalBytes: 0
                        )
                    }
                }

                Thread.sleep(forTimeInterval: 0.05)
            }

            self.activeTasksLock.lock()
            self.activeInstallTasks.removeValue(forKey: moduleName)
            self.activeTasksLock.unlock()

            let isSuccess = engine.isModuleInstalled(moduleName: moduleName)

            // ── Finalize: message + end Live Activity ───────────────────
            DispatchQueue.main.async {
                if isSuccess {
                    if !skipDatabase { self.removePendingInstallation(moduleName: moduleName) }
                    self.messages.send(.installCompleted(moduleName: moduleName))
                    print("✅ [Install] Module '\(moduleName)' successfully installed")

                    self.endLiveActivity(
                        moduleName: moduleName,
                        finalProgress: 1.0,
                        finalStatus: "Done"
                    )
                } else {
                    print("🚨 [Install] Extraction failed for '\(moduleName)'. Check sandbox paths / network.")
                    self.messages.send(.installFailed(moduleName: moduleName))

                    self.endLiveActivity(
                        moduleName: moduleName,
                        finalProgress: Double(max(0, lastReportedProgress)),
                        finalStatus: "Failed"
                    )
                }
            }
        }
    }

    func refreshInstalledModules(completion: @escaping ([XbibleEngine.SwordModule]) -> Void) {
        userInteractionQueue.async { [weak self] in
            guard let self = self, let engine = self.engine else { return }
            let modules = engine.refreshInstalledModules()
            print("🔄 [Refresh] Installed modules count: \(modules.count)")
            DispatchQueue.main.async {
                completion(modules)
            }
        }
    }

    func cancelInstallation(moduleName: String) {
        guard let engine = self.engine else { return }
        userInteractionQueue.async {
            self.activeTasksLock.lock()
            let targetTaskId = self.activeInstallTasks[moduleName]
            if let taskId = targetTaskId {
                print("🛑 [Install] Cancelling \(moduleName) (task \(taskId))")
                engine.cancelTask(taskId: taskId)
                self.activeInstallTasks.removeValue(forKey: moduleName)
            }
            self.activeTasksLock.unlock()

            DispatchQueue.main.async {
                self.removePendingInstallation(moduleName: moduleName)
                self.messages.send(.installCancelled(moduleName: moduleName))

                // Dismiss the Live Activity immediately on cancel.
                self.endLiveActivity(
                    moduleName: moduleName,
                    finalProgress: 0,
                    finalStatus: "Cancelled"
                )
            }
        }
    }

    // MARK: - Live Activity Helpers

    #if canImport(ActivityKit)
    /// Start a Live Activity for the given module. Must be called on the
    /// main thread — the caller does so inside DispatchQueue.main.async.
    private func startLiveActivity(moduleName: String, sourceName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("ℹ️ [LiveActivity] User disabled Live Activities – skipping")
            return
        }

        // If an old one is somehow still alive for this module, end it
        // before opening a new one so we don't stack duplicates.
        if let existing = activeLiveActivities[moduleName] {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            activeLiveActivities.removeValue(forKey: moduleName)
        }

        let attributes = ModuleDownloadAttributes(
            moduleName: moduleName,
            sourceName: sourceName
        )
        let initialState = ModuleDownloadAttributes.ContentState(
            progress: 0,
            status: "Preparing",
            downloadedBytes: 0,
            totalBytes: 0
        )

        do {
            let activity = try Activity<ModuleDownloadAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activeLiveActivities[moduleName] = activity
            print("🔵 [LiveActivity] Started for \(moduleName)")
        } catch {
            print("🚨 [LiveActivity] Failed to start for \(moduleName): \(error)")
        }
    }

    /// Push a state update into the Live Activity. Safe to call from the
    /// main thread — the actual `Activity.update` hop happens on a Task.
    private func updateLiveActivity(
        moduleName: String,
        progress: Double,
        status: String,
        downloadedBytes: Int64,
        totalBytes: Int64
    ) {
        guard let activity = activeLiveActivities[moduleName] else { return }

        let state = ModuleDownloadAttributes.ContentState(
            progress: progress,
            status: status,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// End the Live Activity, keeping the final state visible briefly so
    /// the user sees the outcome before it auto-dismisses.
    private func endLiveActivity(
        moduleName: String,
        finalProgress: Double,
        finalStatus: String
    ) {
        guard let activity = activeLiveActivities[moduleName] else { return }

        let finalState = ModuleDownloadAttributes.ContentState(
            progress: finalProgress,
            status: finalStatus,
            downloadedBytes: 0,
            totalBytes: 0
        )
        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 4)
            )
            print("🔵 [LiveActivity] Ended for \(moduleName) (\(finalStatus))")
        }
        activeLiveActivities.removeValue(forKey: moduleName)
    }
    #else
    // Stubs for non-ActivityKit platforms (macOS). Compile cleanly, do nothing.
    private func startLiveActivity(moduleName: String, sourceName: String) { }
    private func updateLiveActivity(
        moduleName: String,
        progress: Double,
        status: String,
        downloadedBytes: Int64,
        totalBytes: Int64
    ) { }
    private func endLiveActivity(
        moduleName: String,
        finalProgress: Double,
        finalStatus: String
    ) { }
    #endif

    // MARK: - Helpers

    private func updateStep(_ step: EngineStep) {
        DispatchQueue.main.async {
            self.currentStep = step
        }
    }

    private func removePendingInstallation(moduleName: String) {
        let descriptor = FetchDescriptor<PendingInstallation>(
            predicate: #Predicate { $0.moduleName == moduleName }
        )
        if let results = try? modelContext?.fetch(descriptor), let match = results.first {
            modelContext?.delete(match)
            try? modelContext?.save()
        }
    }
}
