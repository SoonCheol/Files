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
