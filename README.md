# SwiftRip-Tools

SwiftRip-Tools is the separate build/package workspace for the command-line tools used by SwiftRip.app.

Its job is to produce known-good, signed, app-bundled artifacts such as:

- HandBrakeCLI
- libdvdcss.2.dylib
- any required runtime support files

SwiftRip.app should consume finished artifacts from this workspace rather than relying on Homebrew, MacPorts, /usr/local/lib, or manually installed tools.

## Current package

The current package set is published from:

```text
https://github.com/fahlman/SwiftRip-Tools/releases/tag/handbrake-1.11.2-libdvdcss-1.6.0
```

It contains:

- HandBrakeCLI 1.11.2
- libdvdcss 1.6.0
- Apple silicon package tarballs pinned by SHA-256 in `Manifest/`

## Contributor bootstrap

Generated tool artifacts are intentionally not committed to Git. On a clean checkout, prepare them with:

```sh
Scripts/bootstrap-tools.zsh
```

The bootstrap script first verifies any existing local artifacts. If they are missing or invalid, it tries to download the pinned tool package for the selected architecture. If the package is unavailable, it falls back to building the tools locally:

- `Artifacts/macos-arm64/HandBrakeCLI`
- `Artifacts/macos-arm64/libdvdcss.2.dylib`

The tools are built for Apple silicon only, with macOS 27 as the minimum. Intel builds were retired because macOS 27 does not run on Intel Macs; Intel packages that were already published stay available from their releases. `SOURCE_OFFER.md` lists the commit to rebuild each earlier release from and the sources it pins.

Force a rebuild with:

```sh
Scripts/bootstrap-tools.zsh --force
```

## HandBrake fork

SwiftRip builds HandBrakeCLI from this pinned fork tag:

```text
https://github.com/fahlman/SwiftRip-HandBrake/tree/swiftrip-handbrake-1.11.2
```

That tag starts from upstream HandBrake 1.11.2 and contains SwiftRip's app-specific `libdvdread` patch. The patch makes HandBrake load `libdvdcss.2.dylib` from:

```text
@executable_path/../Frameworks/libdvdcss.2.dylib
```

That matches SwiftRip.app's bundle layout and avoids relying on `/usr/local/lib`.

## libdvdcss source pin

SwiftRip builds libdvdcss from this pinned source tag:

```text
https://github.com/fahlman/SwiftRip-libdvdcss/tree/swiftrip-libdvdcss-1.6.0
```

That tag points at VideoLAN's upstream libdvdcss 1.6.0 commit:

```text
9de0528e142d6dd31c4d198130d4a48ff3397d2b
```

The build script verifies that exact commit before building `libdvdcss.2.dylib`.

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

The `Upstream Updates` GitHub Actions workflow runs that check every Monday and can also be started manually. When either upstream version is newer than the pinned SwiftRip-Tools version, it creates the matching source tags, applies the single HandBrake app-bundle patch, builds and verifies the Apple silicon package, publishes the SwiftRip-Tools release, updates the repository pins, and dispatches the exact tool revision to SwiftRip.

## Packaging

After a successful local rebuild, create the downloadable tool package with:

```sh
Scripts/package-swiftrip-tools.zsh
```

Publish the generated file from `Packages/` to the GitHub release URL recorded in the matching manifest under `Manifest/`. SwiftRip CI verifies the manifest checksum before extracting the tools and running the full bundle integrity tests.

Package and release names follow `handbrake-<version>-libdvdcss-<version>-macos-<minimum macOS>`. Rebuilding the same tools for a newer macOS therefore publishes a new release and never replaces a package that SwiftRip already pins by checksum.

Use the publish helper to either upload with GitHub CLI or open the exact release page and reveal the package in Finder:

```sh
Scripts/publish-swiftrip-tools.zsh
```


## Source and licenses

- `LICENSE` covers SwiftRip-Tools under GPLv2.
- `SOURCE_OFFER.md` describes source availability and rebuild steps.
- `THIRD_PARTY_NOTICES.md` lists the major upstream components and their licenses.

## SwiftRip integration

SwiftRip.app keeps a small fetch script and manifest copy in its own repository so GitHub Actions can restore the pinned packages during release builds. This repository owns the source/build/package/publish workflow and the release assets referenced by those manifests.
