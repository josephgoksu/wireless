# Wireless

SwiftUI macOS radio app + WidgetKit extension that plays live BBC radio. macOS 15+, Swift 6, no dependencies.

| Path | What |
|---|---|
| `App/Radio.swift` | The model: 60 Hz tick, tuning, AVPlayer stream, `Hiss` static synth, media keys |
| `App/RadioView.swift` | The set: cabinet, grille, card, knobs, keys |
| `Shared/` | Compiled into both targets: stations, BBC metadata fetch, drawn parts (dial, magic eye, key cap, walnut) |
| `Widget/` | Small and medium widgets. Clicks open `wireless://tune/<service id>` |
| `scripts/icon.swift` | Renders the app icon from the shared parts (`make icon`) |

Commands: `make` (build, install to ~/Applications, launch), `make build`, `make icon`. `project.yml` is the source of truth; the `.xcodeproj` is generated and gitignored.

Read `context/` before touching streams or metadata.
