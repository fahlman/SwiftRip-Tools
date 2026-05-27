# Third-Party Notices

SwiftRip-Tools builds, packages, or verifies third-party software components. Those components are copyrighted by their respective authors and are licensed under their own license terms.

## HandBrake / HandBrakeCLI

- Component: HandBrakeCLI
- Project: HandBrake
- Website: https://handbrake.fr/
- Source: https://github.com/HandBrake/HandBrake
- Current SwiftRip-Tools target version: 1.11.1
- License: GNU General Public License version 2
- Use in SwiftRip-Tools: built as the command-line ripping/transcoding engine consumed by SwiftRip.app.

HandBrakeCLI is not authored by the SwiftRip project. HandBrake and HandBrakeCLI remain under the copyright and license notices of the HandBrake project and its contributors.

## libdvdcss

- Component: libdvdcss
- Project: VideoLAN libdvdcss
- Website: https://www.videolan.org/developers/libdvdcss.html
- Source: https://code.videolan.org/videolan/libdvdcss
- Current SwiftRip-Tools target version: 1.5.0
- License: GNU General Public License
- Use in SwiftRip-Tools: built as an app-local dynamic library so SwiftRip.app does not rely on Homebrew, MacPorts, `/usr/local/lib`, `/opt/local/lib`, or other user-installed runtime libraries.

libdvdcss is not authored by the SwiftRip project. libdvdcss remains under the copyright and license notices of the VideoLAN project and its contributors.

## Build Tools

SwiftRip-Tools may use developer-installed build tools such as:

- clang / Xcode command-line tools
- Meson
- Ninja
- Git
- curl
- tar
- lipo
- install_name_tool
- codesign

These tools are used to build artifacts during development. They are not intended to be runtime dependencies of SwiftRip.app.

## Runtime Dependency Rule

SwiftRip.app should not require users to install HandBrake, libdvdcss, Homebrew, MacPorts, or other external runtime packages.

The intended app bundle model is:

```text
SwiftRip.app/
  Contents/
    MacOS/
      SwiftRip
      HandBrakeCLI
    Frameworks/
      libdvdcss.2.dylib
    Resources/
      SwiftRip.json
```

The bundled tools and libraries should be signed together with the app before distribution.

## Source Availability

See `SOURCE_OFFER.md` for source availability and rebuild information.
