# Contributing

Use macOS 14 or later with Swift 6.2 or later.

```sh
swift test
./scripts/build.sh
open "build/Usage Bar.app" --args --show
```

Keep changes small. Add tests when a change affects usage parsing, window selection, or rate-limit handling.
Do not add credentials, account identifiers, session files, or raw authenticated responses to issues, fixtures, or screenshots.
Use synthetic JSON fixtures for tests.

The CI workflow runs tests and checks the release app bundle. It does not use a subscription account.
For changes to sign-in or networking, also check the app locally with your own CLI sign-ins:

```sh
"build/Usage Bar.app/Contents/MacOS/UsageBar" --check
```

For screenshot capture, quit Usage Bar and open the built app with one of these commands:

```sh
open "build/Usage Bar.app" --args --show --appearance light
open "build/Usage Bar.app" --args --show --appearance dark
```

Quit between captures. The appearance flag affects only that app process.
The app still fetches live usage, so inspect each screenshot before sharing it.
Capture only the app popover. Save PNG files in `docs/screenshots` and update the README if the interface changes.

Provider logos come from the sources listed in [the asset notes](Resources/BrandSources/README.md).
Keep those marks intact.
