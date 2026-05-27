# SwiftRipTools

SwiftRipTools is the separate build/package workspace for the command-line tools used by SwiftRip.app.

Its job is to produce known-good, signed, app-bundled artifacts such as:

- HandBrakeCLI
- libdvdcss.2.dylib
- any required runtime support files

SwiftRip.app should consume finished artifacts from this workspace rather than relying on Homebrew, MacPorts, /usr/local/lib, or manually installed tools.

## Current package

The current package set is published from:

```text
https://github.com/fahlman/SwiftRipTools/releases/tag/handbrake-1.11.1-libdvdcss-1.5.0
```

It contains:

- HandBrakeCLI 1.11.1
- libdvdcss 1.5.0
- Apple Silicon and Intel package tarballs pinned by SHA-256 in `Manifest/`

## Contributor bootstrap

Generated tool artifacts are intentionally not committed to Git. On a clean checkout, prepare them with:

```sh
Scripts/bootstrap-tools.zsh
```

The bootstrap script first verifies any existing local artifacts. If they are missing or invalid, it tries to download the pinned tool package for the selected architecture. If the package is unavailable, it falls back to building the tools locally:

- `Artifacts/macos-arm64/HandBrakeCLI`
- `Artifacts/macos-arm64/libdvdcss.2.dylib`

Intel artifacts can be built locally with:

```sh
Scripts/bootstrap-tools.zsh --arch x86_64
```

Force a rebuild with:

```sh
Scripts/bootstrap-tools.zsh --force
```

## HandBrake patching

SwiftRip does not fork HandBrake. App-specific changes are tracked as patch files under:

```text
Patches/HandBrake/
```

`build-handbrakecli.zsh` copies those patches into the extracted HandBrake source before each build. The current `libdvdread` patch makes HandBrake load `libdvdcss.2.dylib` from:

```text
@executable_path/../Frameworks/libdvdcss.2.dylib
```

That matches SwiftRip.app's bundle layout and avoids relying on `/usr/local/lib`.

## Verification

Run:

```sh
Scripts/verify-swiftrip-tools.zsh
```

Verification checks that the generated artifacts match the selected architecture, do not link against `/opt/local`, and that `HandBrakeCLI` contains the app-bundle `libdvdcss` loader path instead of the legacy `/usr/local/lib/libdvdcss.2.dylib` fallback.

Run repository validation with:

```sh
Scripts/validate-repo.zsh
```

## Upstream update monitoring

HandBrake and libdvdcss releases are monitored by:

```sh
Scripts/check-upstream-updates.zsh
```

The `Upstream Updates` GitHub Actions workflow runs that check every Monday and can also be started manually. When either upstream version is newer than the pinned SwiftRipTools version, the workflow opens or updates a GitHub issue with the version table and release checklist. SwiftRipTools still keeps app-specific HandBrake changes as local patches instead of maintaining a long-lived HandBrake fork.

## Packaging

After a successful local rebuild, create the downloadable tool package with:

```sh
Scripts/package-swiftrip-tools.zsh
```

For Intel:

```sh
Scripts/package-swiftrip-tools.zsh --arch x86_64
```

Publish the generated file from `Packages/` to the GitHub release URL recorded in the matching manifest under `Manifest/`. SwiftRip CI verifies the manifest checksum before extracting the tools and running the full bundle integrity tests.

Use the publish helper to either upload with GitHub CLI or open the exact release page and reveal the package in Finder:

```sh
Scripts/publish-swiftrip-tools.zsh
```

For Intel, pass `--arch x86_64`.

## Source and licenses

- `LICENSE` covers SwiftRipTools under GPLv2.
- `SOURCE_OFFER.md` describes source availability and rebuild steps.
- `THIRD_PARTY_NOTICES.md` lists the major upstream components and their licenses.

## SwiftRip integration

SwiftRip.app keeps a small fetch script and manifest copy in its own repository so Xcode Cloud can restore the pinned packages during archive builds. This repository owns the source/build/package/publish workflow and the release assets referenced by those manifests.
