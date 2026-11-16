# Files WinUI 3 Pretendard build-only embedding — 2026-11-16

## Scope
- Keep Files UI, user-selected fonts, sizing, spacing, and icons unchanged.
- Existing `src/Files.App/App.xaml` defines `ContentControlThemeFontFamily` using packaged `ms-appx:///Assets/Fonts/Pretendard-Regular.ttf#Pretendard` with Windows fallback.
- Existing `Files.App.csproj` packages four Pretendard static TTFs; the SIL OFL license is explicitly packaged.
- Source TTF binaries are **never checked into Git**. GitHub Actions fetches them on each run, validates expected Git blob SHA-1 values against a commit-pinned official upstream source, and packages locally. A dedicated .gitignore rule protects against accidental commits.

## Pin and expected Git blob SHA-1
Upstream: `orioncactus/pretendard`, commit `7aeb0698819be2b4097dae8ec8fe6a795e5cf3ae`, path `packages/pretendard/dist/public/static/alternative/`.

| File | Expected Git blob SHA-1 |
| --- | --- |
| Pretendard-Regular.ttf | `01147e9991c91198235e8deefe9c3145dfad8d2a` |
| Pretendard-Medium.ttf | `1db67c68fbd6922637bda59b917ae2d8721971c3` |
| Pretendard-SemiBold.ttf | `9f2690f0979cfcbf1492fc3927536284e346d065` |
| Pretendard-Bold.ttf | `fb07fc65e8e568c60dfd985fb6fcdfd114da4d64` |

The Windows build refuses missing, malformed, or hash-mismatched fonts, and checks that every TTF and `OFL.txt` occurs in the final x64 MSIX payload.

## Permissions and privacy
- Workflow `permissions: contents: read`; checkout does not persist credentials.
- Build does not run `git add`, `git commit`, or `git push`.
- Self-signed test certificate lives in the ephemeral runner temporary directory and is **not** uploaded or committed. A self-signed MSIX may require trusting its publisher certificate for local sideloading.
- Workflow runs manually and upon edits to its own YAML. The GitHub Actions artifacts expire after 14 days.

## Verification limits
Passing Windows CI establishes download/hash checks, source packaging, and MSIX archive inclusion only. It does **not** establish that all WinUI controls use the new font or that the user's Windows display renders Pretendard correctly. Actual rendering, custom font settings, glyph fallback and clipping must be tested on an installed Windows build.

## Handoff
Workflow: `.github/workflows/custom-build.yml`  
App resources: `src/Files.App/App.xaml`  
Packaging: `src/Files.App/Files.App.csproj`  
License: `src/Files.App/Assets/Fonts/OFL.txt`  
Binary ignore: `.gitignore`

## Implementation and verification record (2026-11-16)
- Checked source references in `SoonCheol/D200X-Deck`: `.github/workflows/streamdeck-clean-preview.yml`, `docs/D200X-FONT-EMBEDDING-20261116.md`, `app/streamdeck-editor/style.css`.
- Verified actual Files framework from `Files.App.csproj`: WinUI / Windows App SDK, not DeckForge's Electron/CSS.
- Checked font blob SHA values through official upstream pinned commit GitHub file records.
- Source changes committed: license packaging `380da78`, ignored TTF `02467d2`, this handoff document `3f94114`, workflow `ece2e4c`.
- Verified committed workflow source contains no font vendoring push; permissions reduced to `contents: read` and checkout credentials disabled.
- A `push` trigger scoped to this workflow file was added so that the workflow-change commit can initiate a Windows run; `workflow_dispatch` remains supported.
- **Not yet verified:** Windows runner successfully downloaded font bytes and checked hash; MSBuild/MSIX success; final package archive contains TTFs and OFL; Windows on-device appearance.
- Available GitHub connector cannot dispatch a workflow and its commit-runs lookup returns pull-request runs only; a push-triggered build may not appear there. Confirm status under `https://github.com/SoonCheol/Files/actions/workflows/custom-build.yml`. Do not report build or font rendering as successful without execution evidence.

## 2026-11-16 installer delivery correction
- Previous artifact only uploaded MSIX/dependency payload. CI success was incorrectly treated as a complete installer deliverable.
- Added Inno Setup `Files-Pretendard-Setup-x64.exe` packaging. It bundles the compiled `FilesDev` MSIX, dependent packages, public self-signed publisher certificate, and the local install helper. The build must fail if the EXE cannot be generated.
- The installer runs with user-approved UAC elevation, verifies the packaged `FilesDev` identity, installs the generated certificate in `LocalMachine\\TrustedPeople`, and uses `Add-AppxPackage` for Windows deployment. It does not modify system fonts. **This is an unsigned EXE wrapper around a self-signed MSIX, not the upstream publisher-signed Files classic installer.**
- FilesDev's separate package identity is retained so it is not converted into a replacement for the original Store/sideload package. Installation may still fail on unsupported Windows images or unmet dependencies; a successful build is not proof of runtime installation.
- Added `.github/scripts/Install-FilesDev-Package.ps1` and `.github/scripts/Files-Pretendard-Setup.iss`; workflow additionally publishes artifact `Files-Pretendard-Setup-x64`.
- Commit IDs: helper `0a3a29e`; installer definition `ef4434f`; workflow `39062f7`.
- **Verification pending:** Windows Actions installer packaging run, final EXE artifact presence, successful interactive install, and visual font rendering. Do not report verified until evidence is available.

## 2026-11-16 reported installation failure and fixes
- User's actual setup screenshot shows `Runtime error (at 1:1115): FilesDev package installation failed (exit 1)`. The wrapper masked the underlying PowerShell exception; do not assert the root cause is confirmed from this screenshot.
- Inspected successful #15 job `133094164380` logs: payload includes `Dependencies\\arm64`, `Dependencies\\win32`, `Dependencies\\x64`, and `Dependencies\\x86` runtimes. Prior install helper excluded arm/arm64/x86 but unintentionally allowed `win32`, a plausible x64 deployment problem.
- Changed install helper to select only `Dependencies\\x64` and save PowerShell error details to the extracted payload. Changed Inno setup to display that detail on failure.
- CI now performs a real `Add-AppxPackage` deployment smoke test on the Windows runner and checks `Get-AppxPackage FilesDev` before packaging EXE. This tests runner deployment, not installation on the user's Windows PC.
- Commits: `80bf807` (dependency selection + error diagnostics), `c686924` (error dialog), `59745db` (Windows deployment smoke test).
- **Verification pending:** new runner completion and actual on-device installation; previous setup EXE must not be presented as fixed.

## 2026-11-16 Windows PowerShell 5.1 installation failure
- User's new installer screenshot shows `System.IO.Compression.ZipFile` `TypeNotFound` at `Install-FilesDev-Package.ps1` line 16. The original helper loaded only `System.IO.Compression` before referencing `[System.IO.Compression.ZipFile]`.
- The runner smoke test had invoked `pwsh` (PowerShell 7), while the Inno EXE uses `WindowsPowerShell\\v1.0\\powershell.exe` (Windows PowerShell 5.1). That runtime mismatch allowed CI to succeed despite the user's installation failure.
- Fixed the helper to load `System.IO.Compression.FileSystem` explicitly and switched the runner deployment smoke test to the exact Windows PowerShell 5.1 executable used by the final installer. Commit `eb3a032` and `ec055c6`.
- **New build and user installation pending verification.** Do not present older installer artifacts as fixed.
