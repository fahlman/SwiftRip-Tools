# SwiftRipTools Artifact Layout

SwiftRipTools produces finished command-line artifacts for SwiftRip.app.

## Final artifact output

```text
SwiftRipTools/Artifacts/macos-arm64/
  HandBrakeCLI
  libdvdcss.2.dylib
```

## Intended app bundle layout

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

## Rules
- SwiftRip is currently ARM64-only.
- SwiftRip.app must not rely on Homebrew, MacPorts, /usr/local/lib, /opt/local/lib, or user-installed HandBrake.
- SwiftRip.app should consume artifacts produced by SwiftRipTools.
- Tool artifacts should be reproducible.
- Large generated artifacts should not be committed directly to Git.
- The app and bundled tools must be signed together.
- HandBrake source changes should live as tracked patches under `SwiftRipTools/Patches/HandBrake/`, not as edits inside ignored extracted source trees.
- `HandBrakeCLI` must load `libdvdcss.2.dylib` from `@executable_path/../Frameworks/libdvdcss.2.dylib`.
- `Contents/MacOS/libdvdcss.2.dylib` should not exist in the built app bundle.
