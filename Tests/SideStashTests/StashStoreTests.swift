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

    @Test func isolatedStore_usesProvidedTemporaryStashDirectory() {
        let context = makeStore()
        defer { removeDir(context.stashDirectory) }

        #expect(context.store.stashDirectory == context.stashDirectory)
        #expect(context.store.items.isEmpty)
    }
}
