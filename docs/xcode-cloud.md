# Xcode Cloud

iGopherBrowser has an App Store Connect Xcode Cloud workflow:

- App Store Connect app ID: `6474638845`
- Bundle ID: `com.navanchauhan.iGopherBrowser`
- Workflow ID: `9732C072-1CF1-44CF-9A13-19F9CA3FF9BA`
- Workflow name: `Release`
- Repository: `https://github.com/navanchauhan/iGopherBrowser.git`
- Start condition: pushes to `main`

The repository includes Xcode Cloud custom scripts in `ci_scripts/`:

- `ci_post_clone.sh`: prints environment diagnostics and resolves Swift package dependencies.
- `ci_pre_xcodebuild.sh`: applies `CI_BUILD_NUMBER` to `CURRENT_PROJECT_VERSION` and prints key build settings.
- `ci_post_xcodebuild.sh`: prints result/archive/product paths after Xcode finishes.

Useful local App Store Connect CLI checks:

```sh
asc doctor
asc xcode-cloud workflows list --app 6474638845 --output table
asc xcode-cloud workflows view --id 9732C072-1CF1-44CF-9A13-19F9CA3FF9BA --pretty
asc xcode-cloud build-runs list --workflow-id 9732C072-1CF1-44CF-9A13-19F9CA3FF9BA --sort -number --limit 10 --output table
```

Manual run:

```sh
asc xcode-cloud run \
  --workflow-id 9732C072-1CF1-44CF-9A13-19F9CA3FF9BA \
  --branch main \
  --wait
```

