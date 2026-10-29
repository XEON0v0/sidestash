import Foundation
import OSLog
import SwiftUI

struct StashItem: Identifiable, Equatable {
    var id: String { url.path }
    let url: URL
    let name: String
    let icon: NSImage
    /// Light the icon casts onto the glass rims around it (see `GlassLightingScene`);
    /// `nil` for icons with too little color to emit any.
    let light: IconLight?
    let originalURL: URL?

    static func == (lhs: StashItem, rhs: StashItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct BatchOperationResult: Equatable {
    let attemptedCount: Int
    let successCount: Int

    var failureCount: Int {
        attemptedCount - successCount
    }

    static let empty = BatchOperationResult(attemptedCount: 0, successCount: 0)
}

@MainActor
class StashStore: ObservableObject {
    static let shared = StashStore()

    private let fileSystem: FileSystemProvider
    private let logger = Logger(subsystem: "app.sidestash.SideStash", category: "StashStore")
    private let customStashDirectory: URL?
    private let fileWatchingEnabled: Bool

    @Published var items: [StashItem] = []

    private var iconCache: [String: NSImage] = [:]
    private var lightCache: [String: IconLight?] = [:]

    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    private var fileSystemWatcherDescriptor: Int32 = -1
    private var debounceTimer: Timer?

    private var _stashDirectory: URL?

    var stashDirectory: URL {
        if let cached = _stashDirectory { return cached }
        let dir: URL
        if let customStashDirectory {
            dir = customStashDirectory
        } else if let appSupport = fileSystem.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            dir = appSupport.appendingPathComponent("SideStash/Stash")
        } else {
            dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("SideStash/Stash")
        }
        _stashDirectory = dir
        return dir
    }

    private var metadataURL: URL {
        stashDirectory.appendingPathComponent(".metadata.json")
    }

    init(
        fileSystem: FileSystemProvider = FileManager.default,
        stashDirectory: URL? = nil,
        enableFileWatching: Bool = true
    ) {
        self.fileSystem = fileSystem
        self.customStashDirectory = stashDirectory
        self.fileWatchingEnabled = enableFileWatching
        ensureDirectoryExists()
        refreshItems()
        if fileWatchingEnabled {
            startFileWatching()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            self.stopFileWatching()
        }
    }

    private func ensureDirectoryExists() {
        do {
            try fileSystem.createDirectory(at: stashDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create stash directory: \(error.localizedDescription)")
        }
    }

    private func loadMetadata() -> [String: String] {
        let data: Data
        do {
            data = try Data(contentsOf: metadataURL)
        } catch {
            logger.error("Failed to read metadata file: \(error.localizedDescription)")
            return [:]
        }
        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                return dict
            }
        } catch {
            logger.error("Failed to parse metadata JSON: \(error.localizedDescription)")
        }
        return [:]
    }

    private func saveMetadata(_ dict: [String: String]) {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict)
        } catch {
            logger.error("Failed to serialize metadata: \(error.localizedDescription)")
            return
        }
        let tempURL = metadataURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try fileSystem.replaceItemAt(metadataURL, withItemAt: tempURL, backupItemName: nil, options: [])
        } catch {
            do {
                try data.write(to: metadataURL)
            } catch {
                logger.error("Failed to save metadata file: \(error.localizedDescription)")
            }
        }
    }

    func refreshItems() {
        let contents: [URL]
        do {
            contents = try fileSystem.contentsOfDirectory(at: stashDirectory, includingPropertiesForKeys: nil)
        } catch {
            logger.error("Failed to read stash directory: \(error.localizedDescription)")
            items = []
            return
        }

        let metadata = loadMetadata()

        items = contents
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .compactMap { url in
                let name = url.lastPathComponent
                let icon: NSImage
                if let cached = iconCache[url.path] {
                    icon = cached
                } else {
                    let loaded = NSWorkspace.shared.icon(forFile: url.path)
                    loaded.size = NSSize(width: 48, height: 48)
                    iconCache[url.path] = loaded
                    icon = loaded
                }
                let light: IconLight?
                if let cached = lightCache[url.path] {
                    light = cached
                } else {
                    light = IconLightSampler.light(from: icon)
                    lightCache[url.path] = light
                }
                let originalPath = metadata[name]
                let originalURL = originalPath.map { URL(fileURLWithPath: $0) }
                return StashItem(url: url, name: name, icon: icon, light: light, originalURL: originalURL)
            }
            .sorted { $0.name < $1.name }

        let currentPaths = Set(items.map(\.id))
        iconCache = iconCache.filter { currentPaths.contains($0.key) }
        lightCache = lightCache.filter { currentPaths.contains($0.key) }
    }

    private func startFileWatching() {
        let path = stashDirectory.path
        fileSystemWatcherDescriptor = open(path, O_EVTONLY)
        guard fileSystemWatcherDescriptor >= 0 else { return }

        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileSystemWatcherDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        watcher.setEventHandler { [weak self] in
            self?.debounceRefresh()
        }
        watcher.setCancelHandler { [weak self] in
            if self?.fileSystemWatcherDescriptor ?? -1 >= 0 {
                close(self?.fileSystemWatcherDescriptor ?? -1)
                self?.fileSystemWatcherDescriptor = -1
            }
        }
        watcher.resume()
        fileSystemWatcher = watcher
    }

    private func debounceRefresh() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.refreshItems()
            }
        }
    }

    private func stopFileWatching() {
        fileSystemWatcher?.cancel()
        fileSystemWatcher = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    func stash(url sourceURL: URL) {
        guard !sourceURL.path.hasPrefix(stashDirectory.path) else {
            logger.info("Cannot stash a file already in stash: \(sourceURL)")
            return
        }
        ensureDirectoryExists()
        let destinationURL = uniqueDestinationURL(for: sourceURL.lastPathComponent)

        var stashSuccess = false
        do {
            try fileSystem.moveItem(at: sourceURL, to: destinationURL)
            stashSuccess = true
        } catch {
            do {
                try fileSystem.copyItem(at: sourceURL, to: destinationURL)
                do {
                    try fileSystem.removeItem(at: sourceURL)
                } catch {
                    logger.error("Failed to remove source after copy: \(error.localizedDescription)")
                }
                stashSuccess = true
            } catch {
                logger.error("Failed to stash \(sourceURL): \(error.localizedDescription)")
                return
            }
        }

        guard stashSuccess else { return }

        var metadata = loadMetadata()
        metadata[destinationURL.lastPathComponent] = sourceURL.path
        saveMetadata(metadata)

        refreshItems()
    }

    func finalizeDrag(item: StashItem) {
        // Poll to detect whether Finder finished the drag-out file operation.
        // 0.05 s interval, 2 s timeout.
        Task { @MainActor in
            let pollInterval: TimeInterval = 0.05
            let maxTimeout: TimeInterval = 2.0
            let deadline = Date().addingTimeInterval(maxTimeout)

            while Date() < deadline {
                if !fileSystem.fileExists(atPath: item.url.path) {
                    // Successfully dragged out — clean up metadata
                    self.removeMetadata(for: item)
                    self.refreshItems()
                    return
                }
                do {
                    try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                } catch {
                    logger.error("Task.sleep interrupted during drag polling: \(error.localizedDescription)")
                    break
                }
            }

            // Timeout — file still in stash, restore to original location
            _ = self.restoreItemToOriginalLocation(item)
            self.removeMetadata(for: item)
            self.refreshItems()
        }
    }

    func delete(item: StashItem) {
        do {
            _ = try fileSystem.trashItem(at: item.url)
            removeMetadata(for: item)
        } catch {
            logger.error("Failed to delete item \(item.name): \(error.localizedDescription)")
        }
        refreshItems()
    }

    func trashAll() -> BatchOperationResult {
        let snapshot = items
        guard !snapshot.isEmpty else { return .empty }

        var successCount = 0
        for item in snapshot {
            do {
                _ = try fileSystem.trashItem(at: item.url)
                removeMetadata(for: item)
                successCount += 1
            } catch {
                logger.error("Failed to trash item \(item.name): \(error.localizedDescription)")
            }
        }

        refreshItems()
        return BatchOperationResult(attemptedCount: snapshot.count, successCount: successCount)
    }

    func restoreToOriginal(item: StashItem) {
        if restoreItemToOriginalLocation(item) {
            removeMetadata(for: item)
            refreshItems()
        }
    }

    func restoreAllToOriginal() -> BatchOperationResult {
        let snapshot = items
        guard !snapshot.isEmpty else { return .empty }

        var successCount = 0
        for item in snapshot {
            if restoreItemToOriginalLocation(item) {
                removeMetadata(for: item)
                successCount += 1
            }
        }

        refreshItems()
        return BatchOperationResult(attemptedCount: snapshot.count, successCount: successCount)
    }

    func moveAll(to destinationDirectory: URL) -> BatchOperationResult {
        let snapshot = items
        guard !snapshot.isEmpty else { return .empty }

        var successCount = 0
        for item in snapshot {
            let destinationURL = uniqueURL(at: destinationDirectory, for: item.name)
            do {
                try fileSystem.moveItem(at: item.url, to: destinationURL)
                removeMetadata(for: item)
                successCount += 1
            } catch {
                logger.error("Failed to move \(item.name) to current Finder folder: \(error.localizedDescription)")
            }
        }

        refreshItems()
        return BatchOperationResult(attemptedCount: snapshot.count, successCount: successCount)
    }

    /// Zips every stashed file into `destinationDirectory`; the stash is unchanged.
    func exportArchive(to destinationDirectory: URL) async -> Result<URL, Error> {
        let files = items.map(\.url)
        return await Task.detached(priority: .userInitiated) {
            Result {
                try StashArchiveExporter.exportArchive(of: files, to: destinationDirectory)
            }
        }.value
    }

    private func uniqueDestinationURL(for filename: String) -> URL {
        uniqueURL(at: stashDirectory, for: filename)
    }

    private func removeMetadata(for item: StashItem) {
        var metadata = loadMetadata()
        metadata.removeValue(forKey: item.name)
        saveMetadata(metadata)
    }

    @discardableResult
    private func restoreItemToOriginalLocation(_ item: StashItem) -> Bool {
        guard let originalURL = item.originalURL else { return false }

        let parentDir = originalURL.deletingLastPathComponent()
        if !fileSystem.fileExists(atPath: parentDir.path) {
            do {
                try fileSystem.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create parent directory for restore: \(error.localizedDescription)")
            }
        }

        let restoreURL = uniqueURL(at: parentDir, for: originalURL.lastPathComponent)
        do {
            try fileSystem.moveItem(at: item.url, to: restoreURL)
            return true
        } catch {
            logger.error("Failed to restore \(item.name) to \(restoreURL): \(error.localizedDescription)")
            return false
        }
    }

    private func uniqueURL(at directory: URL, for filename: String) -> URL {
        Self.uniqueURL(at: directory, for: filename) { fileSystem.fileExists(atPath: $0) }
    }

    /// `filename` in `directory`, or `"name 2.ext"`, `"name 3.ext"`… when taken.
    nonisolated static func uniqueURL(
        at directory: URL,
        for filename: String,
        fileExists: (String) -> Bool
    ) -> URL {
        var destination = directory.appendingPathComponent(filename)
        let fileExtension = (filename as NSString).pathExtension
        let baseName = (filename as NSString).deletingPathExtension

        var counter = 2
        while fileExists(destination.path) {
            let newName = fileExtension.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(fileExtension)"
            destination = directory.appendingPathComponent(newName)
            counter += 1
        }
        return destination
    }
}
