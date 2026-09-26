# SwiftRip-Tools — Repository Instructions

Read the shared `AGENTS.md` first. The local folder is `SwiftRipTools`; the
GitHub repository is `fahlman/SwiftRip-Tools`. Read `README.md`,
`Notes/ArtifactLayout.md`, `SOURCE_OFFER.md`, and `SECURITY.md`.

## Ownership and artifacts

- This repository builds, verifies, packages, and publishes HandBrakeCLI,
  libdvdcss, and their runtime support for SwiftRip. The app consumes completed
  artifacts; it must not depend on Homebrew, MacPorts, or local runtime libraries.
- `Scripts/` owns the build and packaging workflow; `Manifest/` owns package
  URLs and checksums. `Source/`, `Build/`, `Artifacts/`, and `Packages/` contain
  source workspaces or generated outputs; do not treat generated binaries as
  source changes.
- Preserve exact upstream/fork revision checks and the app-relative libdvdcss
  loader patch. Verify the pins in the current scripts and manifests rather than
  treating a README version as proof of the revision being built.
- Keep Apple Silicon and Intel packages distinct and checksum-pinned. Updates
  must keep the consumer manifest, published assets, notices, and source offer
  consistent.

## Existing commands

- `Scripts/bootstrap-tools.zsh` verifies or restores the pinned artifacts and
  can fall back to building; `--arch x86_64` selects Intel.
- `Scripts/verify-swiftrip-tools.zsh` checks the generated artifacts, architecture,
  linkage, and app-bundle loader path.
- `Scripts/validate-repo.zsh` performs repository validation.
- `Scripts/package-swiftrip-tools.zsh` packages completed builds;
  `Scripts/publish-swiftrip-tools.zsh` publishes them. Packaging or publication
  is distinct from source validation.
- Upstream monitoring and automatic update workflows can create source tags,
  build packages, publish releases, and dispatch updates to SwiftRip. Read the
  workflow before invoking it; it is not a read-only version check.
- Follow `SECURITY.md` for private vulnerability reporting. Preserve the exact
  source and license trail for every published executable package.

## Toolchain and platforms

Configuration inspected on 2026-09-25 in `Scripts/build-handbrakecli.zsh`
and `Scripts/build-libdvdcss.zsh`. These build native upstream tools using
shell/build-system wrappers; Swift compiler and language-mode requirements
do not apply.

- Selected local tools: Xcode 27.0 (`27A266a`), Apple Clang 21.0.0
  (`clang-2100.3.34.2`), macOS SDK 27.0. These are observations, not artifact pins.
- SDK: the inspected scripts do not pin an SDK version. Record the SDK and
  compiler actually selected for each artifact build.
- Deployment target: the libdvdcss cross-build file explicitly sets macOS 13.0.
  The HandBrakeCLI script does not specify an explicit minimum; inspect its
  generated upstream configuration and the built artifact before reporting one.
- Preserve both arm64 and x86_64 artifact contracts. Toolchain/deployment changes
  belong in separate work, including any needed consumer compatibility updates.

Follow the shared latest-stable policy where applicable; the local tool versions
are a dated snapshot.
