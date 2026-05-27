# Source Offer

SwiftRip-Tools is free software distributed under the GNU General Public License version 2. See `LICENSE` for the full license text.

This repository provides the source/build workspace for the command-line tools bundled with SwiftRip.app.

## SwiftRip-Tools Source

The SwiftRip-Tools source repository is:

```text
https://github.com/fahlman/SwiftRip-Tools
```

It includes build scripts, package manifests, patch files, and documentation needed to inspect, modify, rebuild, package, and verify the bundled tool artifacts consumed by SwiftRip.

## Third-Party Source

SwiftRip-Tools currently builds:

- HandBrakeCLI from HandBrake source release `1.11.1`
- libdvdcss from VideoLAN source release `1.5.0`

The exact upstream URLs and SHA-256 checksums are recorded in:

```text
Scripts/build-handbrakecli.zsh
Scripts/build-libdvdcss.zsh
```

Generated source archives, extracted source trees, build folders, binary artifacts, and package tarballs are intentionally not committed to Git. They are reproduced locally by the build scripts or downloaded from the pinned GitHub release assets referenced by `Manifest/`.

## Project Patches

SwiftRip-Tools does not fork HandBrake. App-specific changes are tracked as patch files under:

```text
Patches/HandBrake/
```

The current patch adjusts HandBrake's libdvdread contribution so the bundled `HandBrakeCLI` can load `libdvdcss.2.dylib` from SwiftRip.app's `Contents/Frameworks` directory instead of relying on `/usr/local/lib`.

## Rebuilding

Build and verify Apple Silicon artifacts:

```sh
Scripts/bootstrap-tools.zsh --force
```

Build and verify Intel artifacts:

```sh
Scripts/bootstrap-tools.zsh --arch x86_64 --force
```

Package a rebuilt artifact set:

```sh
Scripts/package-swiftrip-tools.zsh
Scripts/package-swiftrip-tools.zsh --arch x86_64
```

Publish package assets to the GitHub release named by the manifests:

```sh
Scripts/publish-swiftrip-tools.zsh
Scripts/publish-swiftrip-tools.zsh --arch x86_64
```

## Binary Distribution Requirement

If SwiftRip distributes binaries built from these tools, recipients must be able to obtain the corresponding source code for the exact shipped binaries.

The intended approach is to keep the source/build scripts, manifests, patch files, and release provenance public in this repository and to identify the exact third-party component versions used by each published package.

## No Warranty

SwiftRip-Tools and its bundled GPL-covered components are provided without warranty. See `LICENSE` for the full GPLv2 warranty disclaimer.
