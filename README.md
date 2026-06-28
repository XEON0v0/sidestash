# SideStash

SideStash is a macOS menu bar app that gives Finder a temporary floating file stash. Drag files out of Finder to reveal the stash, drop them in, then drag them back out when you need them again.

## Features

- Menu-bar-only macOS app with no Dock icon.
- Temporary stash folder under `~/Library/Application Support/SideStash/Stash/`.
- Drag files into the floating panel to move them into the stash.
- Drag files back out to restore them through Finder.
- Collision-safe file names when duplicate names are stashed.
- English and Simplified Chinese localization.

## Requirements

- macOS 14 or newer
- Swift toolchain compatible with Swift Package Manager

## Build

```bash
swift build -c release
```

## Package The App

```bash
./build_app.sh
open SideStash.app
```

## Permissions

SideStash uses global mouse monitoring to detect Finder drags and optional Finder window integration to attach the stash panel near the active Finder window. macOS may ask for Accessibility permission for the Finder integration.

## Data And Privacy

SideStash stores files locally in your user Library folder and writes local metadata so files can be restored to their original paths. It does not include analytics, networking, or cloud sync.

See `PRIVACY.md` for details.

## Development

```bash
swift test
```

## License

See `LICENSE`.
