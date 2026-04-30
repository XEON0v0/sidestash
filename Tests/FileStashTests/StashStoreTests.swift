import Testing
@testable import FileStash

@Test func infrastructureSmokeTest() {
    #expect(true)
}

@MainActor
struct StashStoreTests {
    let store = StashStore.shared

    func cleanupStashedFiles(_ names: Set<String>) {
        for name in names {
            removeFile(store.stashDirectory.appendingPathComponent(name))
        }
        store.refreshItems()
    }

    // MARK: - Collision-safe naming

    @Test func stash_fileWithExtension_collisionGeneratesNumberedName() {
        let dir1 = makeTempDir()
        let dir2 = makeTempDir()

        let file1 = makeTempFile(named: "test.txt", in: dir1, content: "content1")
        let file2 = makeTempFile(named: "test.txt", in: dir2, content: "content2")

        defer {
            cleanupStashedFiles(["test.txt", "test 2.txt"])
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
        let dir1 = makeTempDir()
        let dir2 = makeTempDir()

        let file1 = makeTempFile(named: "filename", in: dir1, content: "content1")
        let file2 = makeTempFile(named: "filename", in: dir2, content: "content2")

        defer {
            cleanupStashedFiles(["filename", "filename 2"])
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
        let dir = makeTempDir()
        let tempFile = makeTempFile(named: "report.pdf", in: dir, content: "data")

        makeTempFile(named: "report.pdf", in: store.stashDirectory, content: "existing")

        defer {
            cleanupStashedFiles(["report.pdf", "report 2.pdf"])
            removeDir(dir)
        }

        store.stash(url: tempFile)
        #expect(store.items.map(\.name).contains("report 2.pdf"))
    }

    // MARK: - Self-stash rejection

    @Test func stash_fileInsideStashDirectory_isRejected() {
        let fileInStash = makeTempFile(
            named: "self_stash_test.txt",
            in: store.stashDirectory,
            content: "should not stash me"
        )

        let countBefore = store.items.count
        store.stash(url: fileInStash)
        #expect(store.items.count == countBefore)

        removeFile(fileInStash)
    }

    // MARK: - Error behavior

    @Test func loadMetadata_whenFileMissing_returnsEmpty() {
        let metadataURL = store.stashDirectory.appendingPathComponent(".metadata.json")
        removeFile(metadataURL)

        store.refreshItems()

        #expect(store.items.isEmpty)
    }

    @Test func saveMetadata_roundTrip_restoresOriginalPath() {
        let dir = makeTempDir()
        let file = makeTempFile(named: "roundtrip.md", in: dir, content: "roundtrip content")

        defer {
            cleanupStashedFiles(["roundtrip.md"])
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
        let nonexistentURL = makeNonexistentFileURL()
        let countBefore = store.items.count

        store.stash(url: nonexistentURL)

        #expect(store.items.count == countBefore)
        let orphan = store.stashDirectory.appendingPathComponent(nonexistentURL.lastPathComponent)
        #expect(!fileExists(at: orphan))
    }

    // MARK: - finalizeDrag polling

    @Test func finalizeDrag_fileRemovedFromStash_cleansUpMetadata() async {
        let dir = makeTempDir()
        let file = makeTempFile(named: "dragout_success.txt", in: dir, content: "dragged out")

        defer {
            cleanupStashedFiles(["dragout_success.txt"])
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
        let dir = makeTempDir()
        let file = makeTempFile(named: "dragout_timeout.txt", in: dir, content: "should restore")

        defer {
            cleanupStashedFiles(["dragout_timeout.txt"])
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
}
