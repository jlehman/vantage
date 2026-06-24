import ComposableArchitecture
import Foundation
import Testing

@testable import SupacodeSettingsShared
@testable import vantage

@MainActor
@Suite(.serialized)
struct WorktreeCreationPromptFeatureTests {
  private func makeState(
    automaticBaseRef: String = "origin/main",
    defaultBranch: String? = "main",
    remoteNames: [String] = ["origin"],
    branchMenu: BaseRefBranchMenu? = nil,
    selectedBaseRef: String? = nil,
    defaultWorktreeBaseDirectory: String = "/tmp/repo/.worktrees",
    title: String = "",
    color: RepositoryColor? = nil
  ) -> WorktreeCreationPromptFeature.State {
    var state = WorktreeCreationPromptFeature.State(
      repositoryID: "/tmp/repo/",
      repositoryRootURL: URL(fileURLWithPath: "/tmp/repo"),
      repositoryName: "repo",
      automaticBaseRef: automaticBaseRef,
      defaultBranch: defaultBranch,
      remoteNames: remoteNames,
      branchMenu: branchMenu,
      branchName: "",
      selectedBaseRef: selectedBaseRef,
      fetchOrigin: true,
      defaultWorktreeBaseDirectory: defaultWorktreeBaseDirectory,
      validationMessage: nil
    )
    state.title = title
    state.color = color
    return state
  }

  @Test func baseRefSelectedUpdatesSelectionAndClearsValidation() async {
    var state = makeState()
    state.validationMessage = "stale"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.baseRefSelected("origin/feature")) {
      $0.selectedBaseRef = "origin/feature"
      $0.validationMessage = nil
    }
    await store.send(.baseRefSelected(nil)) {
      $0.selectedBaseRef = nil
    }
  }

  @Test func baseRefMenuLabelPrefersSelectionThenAuto() {
    #expect(makeState(selectedBaseRef: nil).baseRefMenuLabel == "origin/main")
    #expect(makeState(selectedBaseRef: "dev").baseRefMenuLabel == "dev")
    #expect(makeState(automaticBaseRef: "", selectedBaseRef: nil).baseRefMenuLabel == "Auto")
  }

  @Test func isSelectedBaseRefLocalClassifiesRemoteVsLocal() {
    // Auto resolves to the remote default -> not local.
    #expect(makeState(selectedBaseRef: nil).isSelectedBaseRefLocal == false)
    // A remote-tracking ref -> not local.
    #expect(makeState(selectedBaseRef: "origin/feature").isSelectedBaseRefLocal == false)
    // A local branch -> local.
    #expect(makeState(selectedBaseRef: "main").isSelectedBaseRefLocal == true)
    // Auto resolving to a local branch (no remotes) -> local.
    #expect(
      makeState(automaticBaseRef: "main", remoteNames: [], selectedBaseRef: nil)
        .isSelectedBaseRefLocal == true
    )
  }

  @Test func createButtonTappedThreadsSelectedBaseRef() async {
    let store = TestStore(initialState: makeState(selectedBaseRef: "origin/dev")) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.set(\.branchName, "feature/new")) {
      $0.branchName = "feature/new"
    }
    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submit(
          repositoryID: "/tmp/repo/",
          branchName: "feature/new",
          baseRef: "origin/dev",
          fetchOrigin: true,
          placement: WorktreePlacementOverride(name: nil, path: nil),
          title: nil,
          color: nil
        )
      )
    )
  }

  @Test func createButtonTappedForcesFetchOffForLocalBaseRef() async {
    // fetchOrigin is true but the selected ref is local: submit must coerce it
    // off to match the disabled toggle (there is nothing to fetch).
    let store = TestStore(initialState: makeState(selectedBaseRef: "main")) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.set(\.branchName, "feature/new")) {
      $0.branchName = "feature/new"
    }
    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submit(
          repositoryID: "/tmp/repo/",
          branchName: "feature/new",
          baseRef: "main",
          fetchOrigin: false,
          placement: WorktreePlacementOverride(name: nil, path: nil),
          title: nil,
          color: nil
        )
      )
    )
  }

  @Test func createButtonTappedThreadsTrimmedPlacementOverrides() async {
    let store = TestStore(initialState: makeState(selectedBaseRef: "origin/dev")) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.set(\.branchName, "feature/new")) {
      $0.branchName = "feature/new"
    }
    await store.send(.set(\.worktreeNameOverride, "  feature_new  ")) {
      $0.worktreeNameOverride = "  feature_new  "
    }
    await store.send(.set(\.worktreePathOverride, " ~/Repos ")) {
      $0.worktreePathOverride = " ~/Repos "
    }
    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submit(
          repositoryID: "/tmp/repo/",
          branchName: "feature/new",
          baseRef: "origin/dev",
          fetchOrigin: true,
          placement: WorktreePlacementOverride(
            name: "feature_new",
            path: "~/Repos"
          ),
          title: nil,
          color: nil
        )
      )
    )
  }

  @Test func worktreeNamePlaceholderTracksTrimmedBranchName() {
    var state = makeState()
    state.branchName = "  feature/foo  "
    #expect(state.worktreeNamePlaceholder == "feature/foo")
  }

  @Test func createButtonTappedRejectsNameOverrideWithSlash() async {
    var state = makeState()
    state.branchName = "feature/new"
    state.worktreeNameOverride = "../escape"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped) {
      $0.validationMessage = "Worktree name can't contain slashes."
    }
  }

  @Test func createButtonTappedRejectsDotDotNameOverride() async {
    var state = makeState()
    state.branchName = "feature/new"
    state.worktreeNameOverride = ".."
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped) {
      $0.validationMessage = "Worktree name is invalid."
    }
  }

  @Test func createButtonTappedRejectsDotGitNameOverride() async {
    var state = makeState()
    state.branchName = "feature/new"
    state.worktreeNameOverride = ".GIT"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped) {
      $0.validationMessage = "Worktree name is invalid."
    }
  }

  @Test func createButtonTappedRejectsBackslashNameOverride() async {
    var state = makeState()
    state.branchName = "feature/new"
    state.worktreeNameOverride = #"foo\bar"#
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped) {
      $0.validationMessage = "Worktree name can't contain slashes."
    }
  }

  @Test func nameValidationErrorAcceptsValidLeafAndEmpty() {
    #expect(WorktreePlacementOverride.nameValidationError(nil) == nil)
    #expect(WorktreePlacementOverride.nameValidationError("   ") == nil)
    #expect(WorktreePlacementOverride.nameValidationError("feature_foo") == nil)
    #expect(WorktreePlacementOverride.nameValidationError(".gitignore") == nil)
  }

  @Test func resolvedWorktreeLocationPreviewFallsBackToBaseAndBranch() {
    var state = makeState(defaultWorktreeBaseDirectory: "/tmp/repo/.worktrees")
    state.branchName = "feature/foo"
    #expect(state.resolvedWorktreeLocationPreview == "/tmp/repo/.worktrees/feature/foo/")
  }

  @Test func resolvedWorktreeLocationPreviewUsesNameOverride() {
    var state = makeState(defaultWorktreeBaseDirectory: "/tmp/repo/.worktrees")
    state.branchName = "feature/foo"
    state.worktreeNameOverride = "feature_foo"
    #expect(state.resolvedWorktreeLocationPreview == "/tmp/repo/.worktrees/feature_foo/")
  }

  // MARK: - Title / Color customization

  @Test func submitTrimsBranchAndForwardsTitleAndColor() async {
    var state = makeState(title: "  Spicy  ", color: .blue)
    state.branchName = "  feature/x  "
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submit(
          repositoryID: "/tmp/repo/",
          branchName: "feature/x",
          baseRef: nil,
          fetchOrigin: true,
          placement: WorktreePlacementOverride(name: nil, path: nil),
          title: "Spicy",
          color: .blue
        )
      )
    )
  }

  @Test func submitPreservesTitleWhenItMatchesBranch() async {
    var state = makeState(title: "feature/x")
    state.branchName = "feature/x"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submit(
          repositoryID: "/tmp/repo/",
          branchName: "feature/x",
          baseRef: nil,
          fetchOrigin: true,
          placement: WorktreePlacementOverride(name: nil, path: nil),
          title: "feature/x",
          color: nil
        )
      )
    )
  }

  @Test func submitWithNoCustomizationForwardsNilTitleAndColor() async {
    var state = makeState()
    state.branchName = "feature/x"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submit(
          repositoryID: "/tmp/repo/",
          branchName: "feature/x",
          baseRef: nil,
          fetchOrigin: true,
          placement: WorktreePlacementOverride(name: nil, path: nil),
          title: nil,
          color: nil
        )
      )
    )
  }

  @Test func emptyBranchNameBlocksSubmit() async {
    let store = TestStore(initialState: makeState()) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped) {
      $0.validationMessage = "Branch name required."
    }
  }

  // MARK: - Existing branch mode

  private func localOnlyBranchMenu(_ branches: [String]) -> BaseRefBranchMenu {
    BaseRefBranchMenu(
      inventory: GitBranchInventory(localBranches: branches),
      hoistedLocalBranch: nil
    )
  }

  @Test func switchingToExistingBranchModeClearsValidation() async {
    var state = makeState()
    state.validationMessage = "stale"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.set(\.creationMode, .existingBranch)) {
      $0.creationMode = .existingBranch
      $0.validationMessage = nil
    }
  }

  @Test func existingBranchSelectedUpdatesSelectionAndClearsValidation() async {
    var state = makeState()
    state.creationMode = .existingBranch
    state.validationMessage = "stale"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.existingBranchSelected("feature/x")) {
      $0.selectedExistingBranch = "feature/x"
      $0.validationMessage = nil
    }
  }

  @Test func createButtonTappedInExistingBranchModeRequiresSelection() async {
    var state = makeState()
    state.creationMode = .existingBranch
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped) {
      $0.validationMessage = "Pick a branch."
    }
  }

  @Test func createButtonTappedInExistingBranchModeSendsSubmitExistingBranchDelegate() async {
    var state = makeState(title: "Pinned", color: .purple)
    state.creationMode = .existingBranch
    state.selectedExistingBranch = "feature/x"
    let store = TestStore(initialState: state) {
      WorktreeCreationPromptFeature()
    }

    await store.send(.createButtonTapped)
    await store.receive(
      .delegate(
        .submitExistingBranch(
          repositoryID: "/tmp/repo/",
          branchName: "feature/x",
          placement: WorktreePlacementOverride(name: nil, path: nil),
          title: "Pinned",
          color: .purple
        )
      )
    )
  }

  @Test func placeholderAndPreviewTrackExistingBranchInExistingMode() {
    var state = makeState(defaultWorktreeBaseDirectory: "/tmp/repo/.worktrees")
    state.creationMode = .existingBranch
    state.selectedExistingBranch = "feature/y"
    // `branchName` (left over from new-branch mode) must not leak into either
    // derivation.
    state.branchName = "ignored/new"
    #expect(state.worktreeNamePlaceholder == "feature/y")
    #expect(state.resolvedWorktreeLocationPreview == "/tmp/repo/.worktrees/feature/y/")
  }

  @Test func availableExistingBranchesExcludesAlreadyCheckedOut() {
    var state = makeState(branchMenu: localOnlyBranchMenu(["main", "feature/x", "feature/y"]))
    state.existingWorktreeBranches = ["feature/x"]
    let available = state.availableExistingBranches
    #expect(available.contains("main"))
    #expect(available.contains("feature/y"))
    #expect(!available.contains("feature/x"))
  }

  @Test func availableExistingBranchesIsEmptyWhenInventoryNotLoaded() {
    let state = makeState()
    #expect(state.availableExistingBranches.isEmpty)
  }
}
