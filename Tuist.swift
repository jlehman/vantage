import ProjectDescription

let tuist = Tuist(
  project: .tuist(
    compatibleXcodeVersions: .upToNextMajor("26.0"),
    swiftVersion: "6.0",
    generationOptions: .options(
      optionalAuthentication: true
    ),
    cacheOptions: .options(
      profiles: .profiles(
        [
          "development": .profile(
            .allPossible,
            except: [
              .named("GhosttyKit"),
            ]
          ),
        ],
        default: .custom("development")
      )
    )
  )
)
