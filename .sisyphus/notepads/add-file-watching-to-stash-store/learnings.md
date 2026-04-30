## Learnings

### DispatchSourceFileSystemObject on @MainActor class
- `DispatchSource.makeFileSystemObjectSource` with `.main` queue works for file system watching on main actor classes.
- Use `open(path, O_EVTONLY)` to get a file descriptor for the directory.
- Event mask `[.write, .delete, .rename]` covers file add/remove/rename.

### Swift Actor Isolation in deinit
- `@MainActor` class `deinit` is NOT automatically considered main-actor-isolated by the compiler.
- Must use `MainActor.assumeIsolated { self.method() }` to call main-actor methods from deinit.
- Same applies to Timer closures fired on main thread — compiler doesn't infer they're on main actor.

### Pre-existing FileSystemProvider breakage
- File 14 `FileManager` extension did not properly conform to `FileSystemProvider` protocol.
- `createDirectory(at:withIntermediateDirectories:)` and `contentsOfDirectory(at:includingPropertiesForKeys:)` in protocol don't match `FileManager`'s signatures (extra default params).
- `replaceItemAt` called wrong underlying method with wrong args.
- Fixed by adding explicit bridging methods that delegate to correct FileManager methods.
