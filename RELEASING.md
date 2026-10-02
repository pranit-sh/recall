# Releasing Recall

Recall is distributed as source code. GitHub automatically attaches ZIP and
tarball source archives to each release, so this process does not require an
Apple Developer Program membership, Developer ID certificate, or notarization.

## Before the First Public Release

Confirm the copyright year and holder in `LICENSE`. Recall is distributed under
the MIT License.

Configure a Git remote before attempting to push a release. This repository does
not currently have one configured.

## Prepare a Release

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` consistently for Debug
   and Release in the app target.
2. Add the release notes to `CHANGELOG.md`.
3. Complete the checks in `ACCESSIBILITY_CHECKS.md`.
4. Confirm clipboard history, contextual usage, and ignored-app settings remain
   local to the Mac.
5. Run the test suite:

   ```shell
   xcodebuild -project Clipboard.xcodeproj \
     -scheme Clipboard \
     -configuration Debug \
     -derivedDataPath DerivedData \
     test CODE_SIGNING_ALLOWED=NO
   ```

6. Create an unsigned release archive as a build verification step:

   ```shell
   xcodebuild -project Clipboard.xcodeproj \
     -scheme Clipboard \
     -configuration Release \
     -archivePath DerivedData/Archives/Recall.xcarchive \
     archive CODE_SIGNING_ALLOWED=NO
   ```

## Publish on GitHub

1. Commit the release changes.
2. Create an annotated tag matching the marketing version:

   ```shell
   git tag -a v0.1.0 -m "Recall 0.1.0"
   git push origin main
   git push origin v0.1.0
   ```

3. On GitHub, create a release from the tag with title `Recall 0.1.0`.
4. Copy the matching section from `CHANGELOG.md` into the release notes.
5. Publish the release. Do not attach an unsigned app binary; users should build
   Recall from source in Xcode.