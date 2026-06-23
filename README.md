# Vantage

Native terminal coding agents command center.

Forked from [supabitapp/supacode](https://github.com/supabitapp/supacode). Outward identity is fully rebranded **and** the on-disk state is isolated from Supacode (different data dir, per-repo config name, URL scheme, UTType, lock owner, CLI binary name), so both apps can coexist without stepping on each other. Internal Swift module/target/directory names still match upstream so future upstream changes can be pulled with minimal merge friction.

## Migrating from Supacode

Vantage starts with a fresh `~/.vantage/` directory and ignores any existing `~/.supacode/` data. To bring your Supacode state across before first launch:

```bash
# Copy global state (sidebar, settings, layouts, repos/, etc.)
cp -R ~/.supacode ~/.vantage

# For each repo with per-repo overrides, also copy supacode.json → vantage.json
# (Vantage reads vantage.json; supacode.json stays in place for Supacode.)
cp /path/to/your/repo/supacode.json /path/to/your/repo/vantage.json
```

**Don't run Vantage and Supacode at the same time** even after isolation — they share GhosttyKit's shared runtime expectations and the same Apple-side keychain entries. Quit one before launching the other.

## Technical Stack

- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [libghostty](https://github.com/ghostty-org/ghostty)

## Requirements

- macOS 26.0+
- Xcode 26.0+ with the Metal Toolchain component installed (`xcodebuild -downloadComponent MetalToolchain`)
- [mise](https://mise.jdx.dev/) (for `tuist`, `zig`, `swiftlint`, etc.)
- [`xcbeautify`](https://github.com/cpisciotta/xcbeautify) on `PATH` (e.g. `brew install xcbeautify`) — the Makefile pipes xcodebuild through it

## First-time setup

```bash
mise trust
mise trust ThirdParty/zmx/mise.toml   # zmx submodule has its own mise.toml
mise install
git submodule update --init --recursive
xcodebuild -downloadComponent MetalToolchain   # one-time, ~700 MB from Apple
```

## Building

```bash
make build-ghostty-xcframework   # Build GhosttyKit from Zig source (slow first run)
make build-app                   # Build macOS app (Debug)
make run-app                     # Build and launch
```

## Development

```bash
make check     # Run swiftformat and swiftlint
make test      # Run tests
make format    # Run swift-format
```
