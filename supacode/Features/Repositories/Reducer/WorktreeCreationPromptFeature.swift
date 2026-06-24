import ComposableArchitecture
import Foundation
import SupacodeSettingsShared

@Reducer
struct WorktreeCreationPromptFeature {
  enum CreationMode: String, Equatable, CaseIterable {
    case newBranch
    case existingBranch
  }

  @ObservableState
  struct State: Equatable {
    let repositoryID: Repository.ID
    /// Canonical repository root, used to resolve relative path overrides in the
    /// preview the same way the reducer does (not reconstructed from the ID).
    let repositoryRootURL: URL
    let repositoryName: String
    /// The resolved auto base ref (e.g. `origin/main`), kept as the default.
    let automaticBaseRef: String
    /// Local branch matching the default ref (e.g. `main`), surfaced as a quick
    /// pick. Cleared once the inventory confirms no such local branch exists.
    var defaultBranch: String?
    /// Configured remote names, used to classify the selected ref as local or remote.
    let remoteNames: [String]
    /// Pre-built local + per-remote branch menu trees; `nil` while still loading.
    var branchMenu: BaseRefBranchMenu?
    var branchName: String
    var selectedBaseRef: String?
    var fetchOrigin: Bool
    /// Switches the form between creating a new branch and checking out an
    /// existing local branch into a new worktree.
    var creationMode: CreationMode = .newBranch
    /// Selection in `existingBranch` mode. `nil` until the user picks one.
    var selectedExistingBranch: String?
    /// Branches that are already checked out in another worktree (including the
    /// primary worktree's HEAD). Filtered out of the existing-branch picker so
    /// the user can't pick a branch `wt` would silently re-use.
    var existingWorktreeBranches: Set<String> = []
    /// Resolved default base directory, used to compute the location preview.
    let defaultWorktreeBaseDirectory: String
    /// Leaf folder name override; empty falls back to the branch name.
    var worktreeNameOverride: String = ""
    /// Parent directory override; empty falls back to `defaultWorktreeBaseDirectory`.
    var worktreePathOverride: String = ""
    /// Disclosure state for the advanced placement section. Collapsed by default.
    var showAdvancedOptions: Bool = false
    /// Disclosure state for the title / color appearance section. Collapsed by default.
    var showAppearanceOptions: Bool = false
    var validationMessage: String?
    var isValidating = false
    /// Optional sidebar customization captured by the new Title / Color
    /// section; transferred to `PendingWorktree.customization` on submit.
    var title: String = ""
    var color: RepositoryColor?

    /// The branch name driving placeholder / preview rendering: the typed
    /// `branchName` in `newBranch` mode, the picker selection in
    /// `existingBranch` mode.
    var effectiveBranchName: String {
      switch creationMode {
      case .newBranch:
        return branchName
      case .existingBranch:
        return selectedExistingBranch ?? ""
      }
    }

    /// Default leaf folder name shown as the name-override placeholder.
    var worktreeNamePlaceholder: String {
      effectiveBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Live validity of the current name override, so the footer can flag an
    /// invalid leaf instead of previewing a destination submit will reject.
    var worktreeNameValidationError: String? {
      WorktreePlacementOverride.nameValidationError(worktreeNameOverride)
    }

    /// Full destination path the worktree will be created at, mirroring the
    /// reducer's resolution.
    var resolvedWorktreeLocationPreview: String {
      SupacodePaths.previewWorktreeDirectory(
        defaultBaseDirectory: URL(filePath: defaultWorktreeBaseDirectory, directoryHint: .isDirectory),
        repositoryRootURL: repositoryRootURL,
        nameOverride: worktreeNameOverride,
        pathOverride: worktreePathOverride,
        branchName: effectiveBranchName
      )
      .path(percentEncoded: false)
    }

    /// Flat set of every selectable local branch ref in `branchMenu`, walking
    /// nested namespace nodes. Empty until the inventory loads.
    var allLocalBranches: Set<String> {
      guard let branchMenu else { return [] }
      var refs: Set<String> = []
      Self.collectRefs(branchMenu.localBranches, into: &refs)
      return refs
    }

    /// Local branches eligible for the existing-branch picker — every local
    /// branch minus the ones already checked out in another worktree (which
    /// `wt` would silently re-use instead of creating a fresh one).
    var availableExistingBranches: Set<String> {
      allLocalBranches.subtracting(existingWorktreeBranches)
    }

    private static func collectRefs(_ nodes: [BranchMenuNode], into refs: inout Set<String>) {
      for node in nodes {
        if let ref = node.ref {
          refs.insert(ref)
        }
        collectRefs(node.children, into: &refs)
      }
    }

    /// Label shown on the base-ref menu button.
    var baseRefMenuLabel: String {
      if let selectedBaseRef, !selectedBaseRef.isEmpty {
        return selectedBaseRef
      }
      return automaticBaseRef.isEmpty ? "Auto" : automaticBaseRef
    }

    var isLoadingBranches: Bool {
      branchMenu == nil
    }

    /// Whether the effective base ref (selection, or the auto ref when unset)
    /// has no remote to fetch from. A name-prefix heuristic, not a true ref
    /// classification: anything without a known `<remote>/` prefix (a local
    /// branch, but also a tag, SHA, or HEAD) counts as "nothing to fetch",
    /// which is exactly when the fetch toggle should be off.
    var isSelectedBaseRefLocal: Bool {
      let ref = selectedBaseRef ?? automaticBaseRef
      guard !ref.isEmpty else { return true }
      return GitReferenceQueries.localBranchName(fromRemoteRef: ref, remoteNames: remoteNames) == nil
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case baseRefSelected(String?)
    case existingBranchSelected(String)
    case cancelButtonTapped
    case createButtonTapped
    case setValidationMessage(String?)
    case setValidating(Bool)
    case delegate(Delegate)
  }

  @CasePathable
  enum Delegate: Equatable {
    case cancel
    case submit(
      repositoryID: Repository.ID,
      branchName: String,
      baseRef: String?,
      fetchOrigin: Bool,
      placement: WorktreePlacementOverride,
      title: String?,
      color: RepositoryColor?
    )
    case submitExistingBranch(
      repositoryID: Repository.ID,
      branchName: String,
      placement: WorktreePlacementOverride,
      title: String?,
      color: RepositoryColor?
    )
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        state.validationMessage = nil
        return .none

      case .baseRefSelected(let ref):
        state.selectedBaseRef = ref
        state.validationMessage = nil
        return .none

      case .existingBranchSelected(let branch):
        state.selectedExistingBranch = branch
        state.validationMessage = nil
        return .none

      case .cancelButtonTapped:
        return .send(.delegate(.cancel))

      case .createButtonTapped:
        switch state.creationMode {
        case .newBranch:
          return Self.submitNewBranch(state: &state)
        case .existingBranch:
          return Self.submitExistingBranch(state: &state)
        }

      case .setValidationMessage(let message):
        state.validationMessage = message
        return .none

      case .setValidating(let isValidating):
        state.isValidating = isValidating
        return .none

      case .delegate:
        return .none
      }
    }
  }

  private static func submitNewBranch(state: inout State) -> Effect<Action> {
    let trimmed = state.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      state.validationMessage = "Branch name required."
      return .none
    }
    guard !trimmed.contains(where: \.isWhitespace) else {
      state.validationMessage = "Branch names can't contain spaces."
      return .none
    }
    let nameOverride = state.worktreeNameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    if let nameError = WorktreePlacementOverride.nameValidationError(nameOverride) {
      state.validationMessage = nameError
      return .none
    }
    state.validationMessage = nil
    let pathOverride = state.worktreePathOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    // Preserve the user's typed title verbatim, even when it equals the
    // branch name. The render is identical (no override → fall back to
    // branch name) but the round-trip into the Customize sheet relies
    // on the value surviving.
    let trimmedTitle = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
    return .send(
      .delegate(
        .submit(
          repositoryID: state.repositoryID,
          branchName: trimmed,
          baseRef: state.selectedBaseRef,
          // Match the disabled toggle: a local base ref has nothing to fetch.
          fetchOrigin: state.isSelectedBaseRefLocal ? false : state.fetchOrigin,
          placement: WorktreePlacementOverride(
            name: nameOverride.isEmpty ? nil : nameOverride,
            path: pathOverride.isEmpty ? nil : pathOverride
          ),
          title: resolvedTitle,
          color: state.color
        )
      )
    )
  }

  private static func submitExistingBranch(state: inout State) -> Effect<Action> {
    guard let branch = state.selectedExistingBranch, !branch.isEmpty else {
      state.validationMessage = "Pick a branch."
      return .none
    }
    let nameOverride = state.worktreeNameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    if let nameError = WorktreePlacementOverride.nameValidationError(nameOverride) {
      state.validationMessage = nameError
      return .none
    }
    state.validationMessage = nil
    let pathOverride = state.worktreePathOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedTitle = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle = trimmedTitle.isEmpty ? nil : trimmedTitle
    return .send(
      .delegate(
        .submitExistingBranch(
          repositoryID: state.repositoryID,
          branchName: branch,
          placement: WorktreePlacementOverride(
            name: nameOverride.isEmpty ? nil : nameOverride,
            path: pathOverride.isEmpty ? nil : pathOverride
          ),
          title: resolvedTitle,
          color: state.color
        )
      )
    )
  }
}
