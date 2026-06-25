# Source Offer

SwiftRip-Tools is free software distributed under the GNU General Public License version 2. See `LICENSE` for the full license text.

This repository provides the source/build workspace for the command-line tools bundled with SwiftRip.app.

## SwiftRip-Tools Source

The SwiftRip-Tools source repository is:

```text
https://github.com/fahlman/SwiftRip-Tools
```

It includes build scripts, package manifests, source provenance, and documentation needed to inspect, modify, rebuild, package, and verify the bundled tool artifacts consumed by SwiftRip.

## Third-Party Source

SwiftRip-Tools currently builds:

- HandBrakeCLI from the SwiftRip-HandBrake fork tag `swiftrip-handbrake-1.11.2`
- libdvdcss from the SwiftRip-libdvdcss source tag `swiftrip-libdvdcss-1.5.0`

The exact upstream URLs, SwiftRip source tags, and commit pins are recorded in:

```text
Scripts/build-handbrakecli.zsh
Scripts/build-libdvdcss.zsh
```

Generated source checkouts, build folders, binary artifacts, and package tarballs are intentionally not committed to Git. They are reproduced locally by the build scripts or downloaded from the pinned GitHub release assets referenced by `Manifest/`.

## HandBrake Fork

SwiftRip's app-specific HandBrake change is tracked in:

```text
https://github.com/fahlman/SwiftRip-HandBrake/tree/swiftrip-handbrake-1.11.2
```

That tag is pinned by commit hash in `Scripts/build-handbrakecli.zsh`. The fork patch adjusts HandBrake's libdvdread contribution so the bundled `HandBrakeCLI` can load `libdvdcss.2.dylib` from SwiftRip.app's `Contents/Frameworks` directory instead of relying on `/usr/local/lib`.

## libdvdcss Source Pin

SwiftRip's libdvdcss source pin is tracked in:

```text
https://github.com/fahlman/SwiftRip-libdvdcss/tree/swiftrip-libdvdcss-1.5.0
```

That tag points at VideoLAN's upstream libdvdcss 1.5.0 commit `c838ca97553aeb8505b7baf02b9a90f8505de212` and is pinned by commit hash in `Scripts/build-libdvdcss.zsh`.

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

The intended approach is to keep the source/build scripts, manifests, fork commit pins, and release provenance public in this repository and to identify the exact third-party component versions used by each published package.

## No Warranty

SwiftRip-Tools and its bundled GPL-covered components are provided without warranty. See `LICENSE` for the full GPLv2 warranty disclaimer.
