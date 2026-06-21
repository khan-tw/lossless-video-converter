# FrameKeep

FrameKeep is a native macOS app for local `MOV` to `MP4` conversion.

## Features

- Native SwiftUI macOS interface
- Batch conversion with standard macOS file panels
- Two modes:
  - `Lossless Rewrap`: remuxes without re-encoding
  - `High Compatibility`: re-encodes to H.264/AAC
- Local-only processing using `ffmpeg`

## Requirements

- macOS 14 or later
- `ffmpeg` available from one of:
  - `FFMPEG_PATH`
  - `/opt/homebrew/bin/ffmpeg`
  - `/usr/local/bin/ffmpeg`
  - `~/.local/bin/ffmpeg`

## Build

```bash
swift build
```

## Run

```bash
./script/build_and_run.sh
```

## Project Structure

- `App/`: app entrypoint and commands
- `Views/`: SwiftUI views
- `Stores/`: UI state and workflows
- `Services/`: ffmpeg integration
- `Support/`: helpers and formatting
- `Tests/`: package tests

## License

MIT
