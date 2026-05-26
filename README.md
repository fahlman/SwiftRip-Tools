# SwiftRipTools

SwiftRipTools is the separate build/package workspace for the command-line tools used by SwiftRip.app.

Its job is to produce known-good, signed, app-bundled artifacts such as:

- HandBrakeCLI
- libdvdcss.2.dylib
- any required runtime support files

SwiftRip.app should consume finished artifacts from this workspace rather than relying on Homebrew, MacPorts, /usr/local/lib, or manually installed tools.

## Contributor bootstrap

Generated tool artifacts are intentionally not committed to Git. On a clean checkout, prepare them with:

```sh
SwiftRipTools/Scripts/bootstrap-tools.zsh
```

The bootstrap script first verifies any existing local artifacts. If they are missing or invalid, it tries to download the pinned tool package for the selected architecture. If the package is unavailable, it falls back to building the tools locally:

- `SwiftRipTools/Artifacts/macos-arm64/HandBrakeCLI`
- `SwiftRipTools/Artifacts/macos-arm64/libdvdcss.2.dylib`

Intel artifacts can be built locally with:

```sh
SwiftRipTools/Scripts/bootstrap-tools.zsh --arch x86_64
```

Force a rebuild with:

```sh
SwiftRipTools/Scripts/bootstrap-tools.zsh --force
```

## HandBrake patching

SwiftRip does not fork HandBrake. App-specific changes are tracked as patch files under:

```text
SwiftRipTools/Patches/HandBrake/
```

`build-handbrakecli.zsh` copies those patches into the extracted HandBrake source before each build. The current `libdvdread` patch makes HandBrake load `libdvdcss.2.dylib` from:

```text
@executable_path/../Frameworks/libdvdcss.2.dylib
```

That matches SwiftRip.app's bundle layout and avoids relying on `/usr/local/lib`.

## Verification

Run:

```sh
SwiftRipTools/Scripts/verify-swiftrip-tools.zsh
```

Verification checks that the generated artifacts match the selected architecture, do not link against `/opt/local`, and that `HandBrakeCLI` contains the app-bundle `libdvdcss` loader path instead of the legacy `/usr/local/lib/libdvdcss.2.dylib` fallback.

## Packaging

After a successful local rebuild, create the downloadable tool package with:

```sh
SwiftRipTools/Scripts/package-swiftrip-tools.zsh
```

For Intel:

```sh
SwiftRipTools/Scripts/package-swiftrip-tools.zsh --arch x86_64
```

Publish the generated file from `SwiftRipTools/Packages/` to the GitHub release URL recorded in the matching manifest under `SwiftRipTools/Manifest/`. CI verifies the manifest checksum before extracting the tools and running the full bundle integrity tests.

Use the publish helper to either upload with GitHub CLI or open the exact release page and reveal the package in Finder:

```sh
SwiftRipTools/Scripts/publish-swiftrip-tools.zsh
```

For Intel, pass `--arch x86_64`.
