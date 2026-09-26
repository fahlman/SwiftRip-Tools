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
- libdvdcss from the SwiftRip-libdvdcss source tag `swiftrip-libdvdcss-1.6.0`

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
https://github.com/fahlman/SwiftRip-libdvdcss/tree/swiftrip-libdvdcss-1.6.0
```

That tag points at VideoLAN's upstream libdvdcss 1.6.0 commit `9de0528e142d6dd31c4d198130d4a48ff3397d2b` and is pinned by commit hash in `Scripts/build-libdvdcss.zsh`.

## Rebuilding

Build and verify Apple Silicon artifacts:

```sh
Scripts/bootstrap-tools.zsh --force
```

Package a rebuilt artifact set:

```sh
Scripts/package-swiftrip-tools.zsh
```

Publish package assets to the GitHub release named by the manifests:

```sh
Scripts/publish-swiftrip-tools.zsh
```

## Earlier Releases

The releases below were published before Intel builds were retired. Their packages, Intel and Apple silicon, stay available unchanged. Rebuild a package from the commit listed for its release, not from the release tag. That commit first recorded the package's SHA-256 in `Manifest/`, and its build scripts pin the sources listed. For the Intel package, run `Scripts/bootstrap-tools.zsh --force --arch x86_64` there.

- `handbrake-1.11.2-libdvdcss-1.6.0`
  - **Rebuild from:** `75e00ec5bc50c790122712f8e41ee03552718ffc`.
  - **HandBrake:** SwiftRip-HandBrake tag `swiftrip-handbrake-1.11.2` (`e1ac9de2cf1aa24c2b8a651b13735c21335a1229`).
  - **libdvdcss:** SwiftRip-libdvdcss tag `swiftrip-libdvdcss-1.6.0` (`9de0528e142d6dd31c4d198130d4a48ff3397d2b`).
  - **Release tag:** points at `ed2b00fdf832018bd39113cc2b57cdccd8e55bd1`, which still pins libdvdcss 1.5.0, because these pins were committed just after publishing.
- `handbrake-1.11.2-libdvdcss-1.5.0`
  - **Rebuild from:** `369f9c3fb2ed3cc60bf391e0e63d7033ad794657`, which is also its release tag.
  - **HandBrake:** `swiftrip-handbrake-1.11.2` (`e1ac9de2cf1aa24c2b8a651b13735c21335a1229`).
  - **libdvdcss:** `swiftrip-libdvdcss-1.5.0` (`c838ca97553aeb8505b7baf02b9a90f8505de212`).
- `handbrake-1.11.1-libdvdcss-1.5.0`
  - **Rebuild from:** `34c8b882640110478bbd8f23f28ed652d4c07083`.
  - **HandBrake:** `swiftrip-handbrake-1.11.1` (`49730cd08f092193ab0e16be8b68be80d7a989ce`).
  - **libdvdcss:** `swiftrip-libdvdcss-1.5.0` (`c838ca97553aeb8505b7baf02b9a90f8505de212`).
  - **Release tag:** points at `0c1315930da19c2af6f2004c8740347b9b381e68`, which builds from the upstream source archives instead. The release's current packages were uploaded later.
- `swiftrip-tools-1`
  - **Rebuild from:** `3e13ef322cd8a7f0125433e167a20fda40e2fa9d`.
  - **HandBrake:** the upstream HandBrake 1.11.1 source archive, plus the libdvdread patch in that commit's `Patches/HandBrake/`.
  - **libdvdcss:** VideoLAN's libdvdcss 1.5.0 archive. Both archives are pinned by SHA-256 in that commit's scripts.
  - **Release tag:** points at `bc0ed0f08124cc568752ecc827b24f07e09fd820`, which pins the same archives after its scripts were reorganized.
  - **Folder layout:** these scripts predate this repository's split from SwiftRip and expect to sit in a folder named `SwiftRipTools`. Run `SwiftRipTools/Scripts/bootstrap-tools.zsh --force --arch x86_64` from that folder's parent, as that commit's README shows.

## Binary Distribution Requirement

If SwiftRip distributes binaries built from these tools, recipients must be able to obtain the corresponding source code for the exact shipped binaries.

The intended approach is to keep the source/build scripts, manifests, fork commit pins, and release provenance public in this repository and to identify the exact third-party component versions used by each published package.

## No Warranty

SwiftRip-Tools and its bundled GPL-covered components are provided without warranty. See `LICENSE` for the full GPLv2 warranty disclaimer.
