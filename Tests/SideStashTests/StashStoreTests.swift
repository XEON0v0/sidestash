import Foundation
import Testing
@testable import SideStash

@Test func infrastructureSmokeTest() {
    #expect(Bool(true))
}

@MainActor
struct StashStoreTests {
    private func makeStore() -> (store: StashStore, stashDirectory: URL) {
        let stashDirectory = makeTempDir()
        let store = StashStore(stashDirectory: stashDirectory, enableFileWatching: false)
        return (store, stashDirectory)
    }

    private func loadMetadata(in stashDirectory: URL) -> [String: String] {
        let metadataURL = stashDirectory.appendingPathComponent(".metadata.json")
        guard
            let data = try? Data(contentsOf: metadataURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            return [:]
        }
        return object
    }

    // MARK: - Collision-safe naming

    @Test func stash_fileWithExtension_collisionGeneratesNumberedName() {
        let context = makeStore()
        let store = context.store
        let dir1 = makeTempDir()
        let dir2 = makeTempDir()

        let file1 = makeTempFile(named: "test.txt", in: dir1, content: "content1")
        let file2 = makeTempFile(named: "test.txt", in: dir2, content: "content2")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir1)
            removeDir(dir2)
        }

        store.stash(url: file1)
        store.stash(url: file2)

        let names = Set(store.items.map { $0.name })
        #expect(names.contains("test.txt"))
        #expect(names.contains("test 2.txt"))
    }

    @Test func stash_fileWithoutExtension_collisionAppendsCounter() {
        let context = makeStore()
        let store = context.store
        let dir1 = makeTempDir()
        let dir2 = makeTempDir()

        let file1 = makeTempFile(named: "filename", in: dir1, content: "content1")
        let file2 = makeTempFile(named: "filename", in: dir2, content: "content2")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir1)
            removeDir(dir2)
        }

        store.stash(url: file1)
        store.stash(url: file2)

        let names = Set(store.items.map { $0.name })
        #expect(names.contains("filename"))
        #expect(names.contains("filename 2"))
    }

    @Test func uniqueURL_atArbitraryDirectory_generatesCollisionSafeName() {
        let context = makeStore()
        let store = context.store
        let dir = makeTempDir()
        let tempFile = makeTempFile(named: "report.pdf", in: dir, content: "data")

        _ = makeTempFile(named: "report.pdf", in: store.stashDirectory, content: "existing")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir)
        }

        store.stash(url: tempFile)
        #expect(store.items.map { $0.name }.contains("report 2.pdf"))
    }

    // MARK: - Self-stash rejection

    @Test func stash_fileInsideStashDirectory_isRejected() {
        let context = makeStore()
        let store = context.store
        let fileInStash = makeTempFile(
            named: "self_stash_test.txt",
            in: store.stashDirectory,
            content: "should not stash me"
        )

        let countBefore = store.items.count
        store.stash(url: fileInStash)
        #expect(store.items.count == countBefore)

        removeDir(context.stashDirectory)
    }

    // MARK: - Error behavior

    @Test func loadMetadata_whenFileMissing_returnsEmpty() {
        let context = makeStore()
        let store = context.store
        let metadataURL = store.stashDirectory.appendingPathComponent(".metadata.json")
        removeFile(metadataURL)

        store.refreshItems()

        #expect(store.items.isEmpty)
        removeDir(context.stashDirectory)
    }

    @Test func saveMetadata_roundTrip_restoresOriginalPath() {
        let context = makeStore()
        let store = context.store
        let dir = makeTempDir()
        let file = makeTempFile(named: "roundtrip.md", in: dir, content: "roundtrip content")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir)
        }

        store.stash(url: file)

        guard let item = store.items.first(where: { $0.name == "roundtrip.md" }) else {
            #expect(Bool(false), "Stashed item not found")
            return
        }
        #expect(item.originalURL?.path == file.path)
    }

    @Test func stash_withNonexistentSource_failsGracefully() {
        let context = makeStore()
        let store = context.store
        let nonexistentURL = makeNonexistentFileURL()
        let countBefore = store.items.count

        store.stash(url: nonexistentURL)

        #expect(store.items.count == countBefore)
        let orphan = store.stashDirectory.appendingPathComponent(nonexistentURL.lastPathComponent)
        #expect(!fileExists(at: orphan))
        removeDir(context.stashDirectory)
    }

    // MARK: - finalizeDrag polling

    @Test func finalizeDrag_fileRemovedFromStash_cleansUpMetadata() async {
        let context = makeStore()
        let store = context.store
        let dir = makeTempDir()
        let file = makeTempFile(named: "dragout_success.txt", in: dir, content: "dragged out")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir)
        }

        store.stash(url: file)

        guard let item = store.items.first(where: { $0.name == "dragout_success.txt" }) else {
            #expect(Bool(false), "Stashed item not found")
            return
        }

        removeFile(item.url)

        store.finalizeDrag(item: item)

        for _ in 0..<20 {
            if !store.items.contains(where: { $0.name == "dragout_success.txt" }) {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(!store.items.contains(where: { $0.name == "dragout_success.txt" }))
    }

    @Test func finalizeDrag_fileStillInStash_restoresToOriginalLocation() async {
        let context = makeStore()
        let store = context.store
        let dir = makeTempDir()
        let file = makeTempFile(named: "dragout_timeout.txt", in: dir, content: "should restore")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir)
        }

        store.stash(url: file)

        guard let item = store.items.first(where: { $0.name == "dragout_timeout.txt" }) else {
            #expect(Bool(false), "Stashed item not found")
            return
        }

        store.finalizeDrag(item: item)

        for _ in 0..<60 {
            if !store.items.contains(where: { $0.name == "dragout_timeout.txt" }) {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(!store.items.contains(where: { $0.name == "dragout_timeout.txt" }))
        #expect(fileExists(at: file))
    }

    @Test func delete_itemRemovesMetadataAfterTrashingFile() {
        let context = makeStore()
        let store = context.store
        let dir = makeTempDir()
        let file = makeTempFile(named: "trash_me.txt", in: dir, content: "trash me")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir)
        }

        store.stash(url: file)

        guard let item = store.items.first(where: { $0.name == "trash_me.txt" }) else {
            #expect(Bool(false), "Stashed item not found")
            return
        }

        #expect(loadMetadata(in: context.stashDirectory)["trash_me.txt"] == file.path)

        store.delete(item: item)

        #expect(!fileExists(at: item.url))
        #expect(!store.items.contains(where: { $0.name == "trash_me.txt" }))
        #expect(loadMetadata(in: context.stashDirectory)["trash_me.txt"] == nil)
    }

    @Test func trashAll_trashesEveryItemAndClearsMetadata() {
        let context = makeStore()
        let store = context.store
        let sourceDir = makeTempDir()
        let fileA = makeTempFile(named: "trash_all_a.txt", in: sourceDir, content: "a")
        let fileB = makeTempFile(named: "trash_all_b.txt", in: sourceDir, content: "b")

        defer {
            removeDir(context.stashDirectory)
            removeDir(sourceDir)
        }

        store.stash(url: fileA)
        store.stash(url: fileB)

        let result = store.trashAll()

        #expect(result.attemptedCount == 2)
        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)
        #expect(store.items.isEmpty)
        #expect(loadMetadata(in: context.stashDirectory).isEmpty)
    }

    @Test func trashAll_emptyStashReturnsZeroResult() {
        let context = makeStore()
        let store = context.store

        defer { removeDir(context.stashDirectory) }

        let result = store.trashAll()

        #expect(result.attemptedCount == 0)
        #expect(result.successCount == 0)
        #expect(result.failureCount == 0)
        #expect(store.items.isEmpty)
    }

    @Test func restoreToOriginal_missingParentDirectory_recreatesDirectoryAndMovesFileBack() {
        let context = makeStore()
        let store = context.store
        let rootDir = makeTempDir()
        let nestedDir = rootDir.appendingPathComponent("nested/folder")
        try? FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let file = makeTempFile(named: "restore_me.txt", in: nestedDir, content: "restore me")

        defer {
            removeDir(context.stashDirectory)
            removeDir(rootDir)
        }

        store.stash(url: file)
        removeDir(rootDir)

        guard let item = store.items.first(where: { $0.name == "restore_me.txt" }) else {
            #expect(Bool(false), "Stashed item not found")
            return
        }

        store.restoreToOriginal(item: item)

        #expect(fileExists(at: file))
        #expect(!store.items.contains(where: { $0.name == "restore_me.txt" }))
        #expect(loadMetadata(in: context.stashDirectory)["restore_me.txt"] == nil)
    }

    @Test func restoreAllToOriginal_restoresItemsToMultipleOriginalFolders() {
        let context = makeStore()
        let store = context.store
        let dirA = makeTempDir()
        let dirB = makeTempDir()
        let fileA = makeTempFile(named: "restore_all_a.txt", in: dirA, content: "a")
        let fileB = makeTempFile(named: "restore_all_b.txt", in: dirB, content: "b")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dirA)
            removeDir(dirB)
        }

        store.stash(url: fileA)
        store.stash(url: fileB)

        let result = store.restoreAllToOriginal()

        #expect(result.attemptedCount == 2)
        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)
        #expect(fileExists(at: fileA))
        #expect(fileExists(at: fileB))
        #expect(store.items.isEmpty)
        #expect(loadMetadata(in: context.stashDirectory).isEmpty)
    }

    @Test func restoreAllToOriginal_leavesUnrestorableItemsInStash() {
        let context = makeStore()
        let store = context.store
        let sourceDir = makeTempDir()
        let file = makeTempFile(named: "restore_all_missing_metadata.txt", in: sourceDir, content: "a")

        defer {
            removeDir(context.stashDirectory)
            removeDir(sourceDir)
        }

        store.stash(url: file)
        let metadataURL = context.stashDirectory.appendingPathComponent(".metadata.json")
        try? "{}".write(to: metadataURL, atomically: true, encoding: .utf8)
        store.refreshItems()

        let result = store.restoreAllToOriginal()

        #expect(result.attemptedCount == 1)
        #expect(result.successCount == 0)
        #expect(result.failureCount == 1)
        #expect(store.items.contains(where: { $0.name == "restore_all_missing_metadata.txt" }))
    }

    @Test func restoreToOriginal_whenDestinationExists_usesCollisionSafeName() {
        let context = makeStore()
        let store = context.store
        let dir = makeTempDir()
        let file = makeTempFile(named: "collision.txt", in: dir, content: "original")

        defer {
            removeDir(context.stashDirectory)
            removeDir(dir)
        }

        store.stash(url: file)
        let conflictingFile = makeTempFile(named: "collision.txt", in: dir, content: "existing")

        guard let item = store.items.first(where: { $0.name == "collision.txt" }) else {
            #expect(Bool(false), "Stashed item not found")
            return
        }

        store.restoreToOriginal(item: item)

        let restoredCollisionURL = dir.appendingPathComponent("collision 2.txt")
        #expect(fileExists(at: conflictingFile))
        #expect(fileExists(at: restoredCollisionURL))
        #expect(!store.items.contains(where: { $0.name == "collision.txt" }))
        #expect(loadMetadata(in: context.stashDirectory)["collision.txt"] == nil)
    }

    @Test func moveAll_movesEveryItemToProvidedFolderAndClearsMetadata() {
        let context = makeStore()
        let store = context.store
        let sourceDir = makeTempDir()
        let destinationDir = makeTempDir()
        let fileA = makeTempFile(named: "move_all_a.txt", in: sourceDir, content: "a")
        let fileB = makeTempFile(named: "move_all_b.txt", in: sourceDir, content: "b")

        defer {
            removeDir(context.stashDirectory)
            removeDir(sourceDir)
            removeDir(destinationDir)
        }

        store.stash(url: fileA)
        store.stash(url: fileB)

        let result = store.moveAll(to: destinationDir)

        #expect(result.attemptedCount == 2)
        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)
        #expect(fileExists(at: destinationDir.appendingPathComponent("move_all_a.txt")))
        #expect(fileExists(at: destinationDir.appendingPathComponent("move_all_b.txt")))
        #expect(store.items.isEmpty)
        #expect(loadMetadata(in: context.stashDirectory).isEmpty)
    }

    @Test func moveAll_whenDestinationNameCollidesUsesNumberedName() {
        let context = makeStore()
        let store = context.store
        let sourceDir = makeTempDir()
        let destinationDir = makeTempDir()
        let file = makeTempFile(named: "move_collision.txt", in: sourceDir, content: "stashed")
        let existing = makeTempFile(named: "move_collision.txt", in: destinationDir, content: "existing")

        defer {
            removeDir(context.stashDirectory)
            removeDir(sourceDir)
            removeDir(destinationDir)
        }

        store.stash(url: file)

        let result = store.moveAll(to: destinationDir)

        #expect(result.successCount == 1)
        #expect(fileExists(at: existing))
        #expect(fileExists(at: destinationDir.appendingPathComponent("move_collision 2.txt")))
        #expect(store.items.isEmpty)
    }

    @Test func isolatedStore_usesProvidedTemporaryStashDirectory() {
        let context = makeStore()
        defer { removeDir(context.stashDirectory) }

        #expect(context.store.stashDirectory == context.stashDirectory)
        #expect(context.store.items.isEmpty)
    }
}
