## NSLocalizedString Migration — 2026-04-30

- Created `en.lproj/` and `zh-Hans.lproj/` with 4 strings each
- Migrated 3 strings in AppDelegate, 1 in StashContentView
- Used `.process` (not `.copy`) in Package.swift for SPM localization
- `swift build` passes, 0 LSP diagnostics
