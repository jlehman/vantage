import ComposableArchitecture
import SupacodeSettingsFeature
import SupacodeSettingsShared
import SwiftUI

struct WorktreeCreationPromptView: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  @FocusState private var isBranchFieldFocused: Bool

  var body: some View {
    Form {
      Section {
        Picker("Mode", selection: $store.creationMode) {
          Text("New branch").tag(WorktreeCreationPromptFeature.CreationMode.newBranch)
          Text("Existing branch").tag(WorktreeCreationPromptFeature.CreationMode.existingBranch)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if store.creationMode == .newBranch {
          TextField("Branch name", text: $store.branchName)
            .focused($isBranchFieldFocused)
            .onSubmit {
              store.send(.createButtonTapped)
            }
        } else {
          WorktreeExistingBranchField(store: store)
        }
      } header: {
        // `NavigationStack` with title and subtitle is bugged inside
        // sheets in macOS 26.*, and this is a nice enough fallback.
        Text("New Worktree")
        Text(headerSubtitle)
      } footer: {
        WorktreeCreationFooter(store: store)
      }
      .headerProminence(.increased)

      if store.creationMode == .newBranch {
        Section {
          WorktreeBaseRefField(store: store)

          Toggle(isOn: $store.fetchOrigin) {
            Text("Fetch remote branch")
            Text(
              "Runs `git fetch` to ensure the base branch is up to date before creating the worktree."
            )
          }
          .disabled(store.isSelectedBaseRefLocal)
        }
      }

      WorktreeAppearanceSection(store: store)

      WorktreeOptionsSection(store: store)
    }
    .formStyle(.grouped)
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      HStack {
        if store.isValidating {
          ProgressView()
            .controlSize(.small)
        }
        Spacer()
        Button("Cancel") {
          store.send(.cancelButtonTapped)
        }
        .keyboardShortcut(.cancelAction)
        .help("Cancel (Esc)")
        Button("Create") {
          store.send(.createButtonTapped)
        }
        .keyboardShortcut(.defaultAction)
        .help("Create (↩)")
        .disabled(store.isValidating)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    }
    .frame(minWidth: 420)
    .task { isBranchFieldFocused = true }
    .dismissSystemColorPanelOnDisappear()
  }

  private var headerSubtitle: String {
    switch store.creationMode {
    case .newBranch:
      return "Create a branch in `\(store.repositoryName)`."
    case .existingBranch:
      return "Check out an existing branch in `\(store.repositoryName)` as a new worktree."
    }
  }
}

private struct WorktreeAppearanceSection: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    Section("Appearance", isExpanded: $store.showAppearanceOptions) {
      TextField("Title", text: $store.title, prompt: Text(store.worktreeNamePlaceholder))
      LabeledContent("Color") {
        ColorSwatchRow(color: $store.color)
      }
    }
  }
}

private struct WorktreeOptionsSection: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    Section("Advanced", isExpanded: $store.showAdvancedOptions) {
      // Title-string fields so tapping the label focuses the field, matching
      // the branch-name field above.
      TextField("Worktree name", text: $store.worktreeNameOverride, prompt: Text(store.worktreeNamePlaceholder))
      TextField("Parent folder", text: $store.worktreePathOverride, prompt: Text(store.defaultWorktreeBaseDirectory))
    }
  }
}

private struct WorktreeCreationFooter: View {
  let store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    if let message = store.validationMessage ?? store.worktreeNameValidationError, !message.isEmpty {
      Text(message)
        .foregroundStyle(.red)
    } else {
      Text(store.resolvedWorktreeLocationPreview)
        .monospaced()
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct WorktreeBaseRefField: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) {
        if store.isLoadingBranches {
          ProgressView()
            .controlSize(.small)
        }
        Menu {
          WorktreeBaseRefMenuContent(store: store)
        } label: {
          Text(store.baseRefMenuLabel)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    } label: {
      Text("Base ref")
      Text("The branch or ref the new worktree will be created from.")
    }
  }
}

private struct WorktreeBaseRefMenuContent: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    WorktreeBaseRefMenuItem(
      store: store,
      ref: nil,
      label: store.automaticBaseRef.isEmpty
        ? Text("Auto")
        : Text(store.automaticBaseRef) + Text(" Auto").foregroundStyle(.secondary)
    )
    if let defaultBranch = store.defaultBranch {
      // Tagged "Local" to distinguish it from the remote-tracking Auto ref above.
      WorktreeBaseRefMenuItem(
        store: store,
        ref: defaultBranch,
        label: Text(defaultBranch) + Text(" Local").foregroundStyle(.secondary)
      )
    }

    Divider()

    if let branchMenu = store.branchMenu {
      if !branchMenu.localBranches.isEmpty {
        Menu("Local") {
          ForEach(branchMenu.localBranches) { node in
            WorktreeBranchNodeMenu(store: store, node: node)
          }
        }
      }
      ForEach(branchMenu.remotes) { remote in
        WorktreeRemoteBranchMenu(store: store, remote: remote)
      }
    } else {
      Text("Loading branches…")
    }
  }
}

private struct WorktreeRemoteBranchMenu: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let remote: BaseRefBranchMenu.Remote

  var body: some View {
    Menu {
      ForEach(remote.branches) { node in
        WorktreeBranchNodeMenu(store: store, node: node)
      }
    } label: {
      Text(remote.name) + Text(" Remote").foregroundStyle(.secondary)
    }
  }
}

private struct WorktreeBranchNodeMenu: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let node: BranchMenuNode

  var body: some View {
    if node.children.isEmpty {
      WorktreeBaseRefMenuItem(store: store, ref: node.ref, label: Text(node.name))
    } else {
      Menu(node.name) {
        // A namespace segment that is also a branch (rare) stays selectable.
        if let ref = node.ref {
          WorktreeBaseRefMenuItem(store: store, ref: ref, label: Text(node.name))
        }
        ForEach(node.children) { child in
          WorktreeBranchNodeMenu(store: store, node: child)
        }
      }
    }
  }
}

private struct WorktreeBaseRefMenuItem: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let ref: String?
  let label: Text

  var body: some View {
    Button {
      store.send(.baseRefSelected(ref))
    } label: {
      if store.selectedBaseRef == ref {
        Label {
          label
        } icon: {
          Image(systemName: "checkmark")
            .accessibilityHidden(true)
        }
      } else {
        label
      }
    }
  }
}

private struct WorktreeExistingBranchField: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) {
        if store.isLoadingBranches {
          ProgressView()
            .controlSize(.small)
        }
        Menu {
          WorktreeExistingBranchMenuContent(store: store)
        } label: {
          Text(menuLabel)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    } label: {
      Text("Branch")
      Text("The existing local branch to check out into the new worktree.")
    }
  }

  private var menuLabel: String {
    if let selected = store.selectedExistingBranch, !selected.isEmpty {
      return selected
    }
    return "Pick a branch"
  }
}

private struct WorktreeExistingBranchMenuContent: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>

  var body: some View {
    if let branchMenu = store.branchMenu {
      let available = store.availableExistingBranches
      if available.isEmpty {
        // Disabled placeholder so the menu doesn't collapse to nothing on
        // repos where every local branch is already checked out.
        Text("No available branches")
      } else {
        ForEach(branchMenu.localBranches) { node in
          WorktreeExistingBranchNodeMenu(store: store, node: node, available: available)
        }
      }
    } else {
      Text("Loading branches…")
    }
  }
}

private struct WorktreeExistingBranchNodeMenu: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let node: BranchMenuNode
  let available: Set<String>

  var body: some View {
    // Skip a leaf whose ref is filtered out; collapse a grouping node whose
    // subtree contributes nothing selectable.
    if let ref = node.ref, node.children.isEmpty {
      if available.contains(ref) {
        WorktreeExistingBranchMenuItem(store: store, ref: ref, label: Text(node.name))
      }
    } else if !node.children.isEmpty {
      if hasAvailableDescendant(node) {
        Menu(node.name) {
          if let ref = node.ref, available.contains(ref) {
            WorktreeExistingBranchMenuItem(store: store, ref: ref, label: Text(node.name))
          }
          ForEach(node.children) { child in
            WorktreeExistingBranchNodeMenu(store: store, node: child, available: available)
          }
        }
      }
    }
  }

  private func hasAvailableDescendant(_ node: BranchMenuNode) -> Bool {
    if let ref = node.ref, available.contains(ref) { return true }
    return node.children.contains(where: hasAvailableDescendant)
  }
}

private struct WorktreeExistingBranchMenuItem: View {
  @Bindable var store: StoreOf<WorktreeCreationPromptFeature>
  let ref: String
  let label: Text

  var body: some View {
    Button {
      store.send(.existingBranchSelected(ref))
    } label: {
      if store.selectedExistingBranch == ref {
        Label {
          label
        } icon: {
          Image(systemName: "checkmark")
            .accessibilityHidden(true)
        }
      } else {
        label
      }
    }
  }
}
