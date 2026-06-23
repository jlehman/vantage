import SwiftUI

struct CLIReferenceView: View {
  var body: some View {
    Form {
      // swiftlint:disable line_length
      Section {
        Text(
          "The \(code("vantage")) command is available in all Vantage terminal sessions. Run \(code("vantage --help")) for built-in usage information."
        )
        .foregroundStyle(.secondary)
        Text(
          "Inside a Vantage terminal, flags default to the current session's IDs. Outside, pass explicit IDs from \(code("vantage worktree list")) or \(code("vantage repo list"))."
        )
        .foregroundStyle(.secondary)
        Text(
          "Commands that create resources (\(code("tab new")), \(code("surface split"))) print the new UUID to stdout. Capture it to target the resource afterward."
        )
        .foregroundStyle(.secondary)
        // swiftlint:enable line_length
      } header: {
        Text("CLI Reference").font(.title.bold())
        Text("Control Vantage from the terminal.")
      }

      CLISection(title: "App", rows: Self.appRows)
      CLISection(title: "Worktree", rows: Self.worktreeRows)
      CLISection(title: "Tab", rows: Self.tabRows)
      CLISection(title: "Surface", rows: Self.surfaceRows)
      CLISection(title: "Repository", rows: Self.repoRows)
      CLISection(title: "Settings", rows: Self.settingsRows)
      CLISection(title: "Socket", rows: Self.socketRows)

      Section("Flags") {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
          ForEach(Self.flagRows) { row in
            GridRow {
              Text(row.command)
                .font(.body.monospaced())
                .gridColumnAlignment(.leading)
              Text(row.description)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
    }
    .textSelection(.enabled)
    .formStyle(.grouped)
    .frame(minWidth: 300)
    .navigationTitle("")
  }

  // MARK: - Row data.

  private static let appRows: [CLIEntry] = [
    .init(command: "vantage", description: "Bring Vantage to front."),
    .init(command: "vantage open", description: "Same as above."),
  ]

  private static let worktreeRows: [CLIEntry] = [
    .init(command: "vantage worktree list [-f]", description: "List worktree IDs. -f for focused only."),
    .init(command: "vantage worktree focus [-w <id>]", description: "Focus a worktree."),
    .init(
      command: "vantage worktree run [-w <id>] [-c <uuid>]",
      description: "Run a script. Defaults to the primary run-kind script; -c targets a specific one."
    ),
    .init(
      command: "vantage worktree stop [-w <id>] [-c <uuid>]",
      description: "Stop a script. Defaults to all run-kind scripts; -c targets a specific one."
    ),
    .init(
      command: "vantage worktree script list [-w <id>]",
      description: "List configured scripts. Underlined rows are currently running."
    ),
    .init(command: "vantage worktree archive [-w <id>]", description: "Archive the worktree."),
    .init(command: "vantage worktree unarchive [-w <id>]", description: "Unarchive the worktree."),
    .init(command: "vantage worktree delete [-w <id>]", description: "Delete the worktree."),
    .init(command: "vantage worktree pin [-w <id>]", description: "Pin the worktree."),
    .init(command: "vantage worktree unpin [-w <id>]", description: "Unpin the worktree."),
  ]

  private static let tabRows: [CLIEntry] = [
    .init(command: "vantage tab list [-w <id>] [-f]", description: "List tab UUIDs. -f for focused only."),
    .init(command: "vantage tab focus [-w <id>] [-t <id>]", description: "Focus a tab."),
    .init(
      command: "vantage tab new [-w <id>] [-i <cmd>] [-n <uuid>]",
      description: "Create a new tab. Prints UUID to stdout."
    ),
    .init(command: "vantage tab close [-w <id>] [-t <id>]", description: "Close a tab."),
  ]

  private static let surfaceRows: [CLIEntry] = [
    .init(
      command: "vantage surface list [-w <id>] [-t <id>] [-f]",
      description: "List surface UUIDs. -f for focused only."
    ),
    .init(
      command: "vantage surface focus [-w <id>] [-t <id>] [-s <id>] [-i <cmd>]",
      description: "Focus a surface."
    ),
    .init(
      command: "vantage surface split [-w <id>] [-t <id>] [-s <id>] [-d h|v] [-i <cmd>] [-n <uuid>]",
      description: "Split a surface. Prints UUID to stdout."
    ),
    .init(
      command: "vantage surface close [-w <id>] [-t <id>] [-s <id>]",
      description: "Close a surface."
    ),
  ]

  private static let repoRows: [CLIEntry] = [
    .init(command: "vantage repo list", description: "List repository IDs."),
    .init(command: "vantage repo open <path>", description: "Open a repository."),
    .init(
      command:
        "vantage repo worktree-new [-r <id>] [--branch <name>] [--base <ref>] [--fetch] "
        + "[--name <folder>] [--location <dir>]",
      description: "Create a worktree in a repository."
    ),
  ]

  private static let settingsRows: [CLIEntry] = [
    .init(command: "vantage settings", description: "Open settings."),
    .init(command: "vantage settings <section>", description: "Open a specific section."),
    .init(command: "vantage settings repo [-r <id>]", description: "Open repository settings."),
  ]

  private static let socketRows: [CLIEntry] = [
    .init(command: "vantage socket", description: "List active socket paths.")
  ]

  private static let flagRows: [CLIEntry] = [
    .init(command: "-w, --worktree", description: "Worktree ID. Defaults to $SUPACODE_WORKTREE_ID."),
    .init(command: "-t, --tab", description: "Tab UUID. Defaults to $SUPACODE_TAB_ID."),
    .init(command: "-s, --surface", description: "Surface UUID. Defaults to $SUPACODE_SURFACE_ID."),
    .init(command: "-c, --script", description: "Script UUID (for `worktree run`/`stop`)."),
    .init(command: "-r, --repo", description: "Repository ID. Defaults to $SUPACODE_REPO_ID."),
    .init(command: "-i, --input", description: "Command to run in the terminal."),
    .init(command: "-d, --direction", description: "Split direction: horizontal (h) or vertical (v)."),
    .init(command: "-n, --id", description: "UUID for a new tab or surface."),
    .init(command: "-f, --focused", description: "Print only the focused item in list commands."),
  ]
}

// MARK: - Components.

private struct CLIEntry: Identifiable {
  let id = UUID()
  let command: String
  let description: String
}

private struct CLISection: View {
  let title: String
  let rows: [CLIEntry]

  var body: some View {
    Section(title) {
      Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
        ForEach(rows) { row in
          GridRow {
            Text(row.command)
              .font(.body.monospaced())
              .gridColumnAlignment(.leading)
            Text(row.description)
              .foregroundStyle(.secondary)
              .gridColumnAlignment(.leading)
          }
        }
      }
    }
  }
}

/// Inline code fragment styled as monospaced primary foreground.
private func code(_ value: String) -> Text {
  Text(value).monospaced().foregroundStyle(.primary)
}
