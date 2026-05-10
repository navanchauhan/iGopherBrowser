# App Store Assets

Generated from local simulator screenshots.

Validate screenshots:

```sh
asc screenshots validate --path app-store-assets/screenshots/en-US/iphone-65 --device-type IPHONE_65
asc screenshots validate --path app-store-assets/screenshots/en-US/ipad-pro-129 --device-type IPAD_PRO_3GEN_129
asc screenshots validate --path app-store-assets/screenshots/en-US/macos --device-type DESKTOP
asc screenshots validate --path app-store-assets/screenshots/en-US/visionos --device-type APPLE_VISION_PRO
```

Upload screenshots:

```sh
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type IPHONE_65 --platform IOS --dry-run
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type IPAD_PRO_3GEN_129 --platform IOS --dry-run
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type DESKTOP --platform MAC_OS --dry-run
asc screenshots upload --app "$ASC_APP_ID" --version "$ASC_VERSION" --path app-store-assets/screenshots --device-type APPLE_VISION_PRO --platform VISION_OS --dry-run
```

Upload previews by localization:

```sh
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/iphone-65 --device-type IPHONE_65 --dry-run
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/ipad-pro-129 --device-type IPAD_PRO_3GEN_129 --dry-run
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/macos --device-type DESKTOP --dry-run
asc video-previews upload --version-localization "$ASC_VERSION_LOCALIZATION_ID" --path app-store-assets/previews/en-US/visionos --device-type APPLE_VISION_PRO --dry-run
```

Current iGopherBrowser 1.2.0 targets discovered with `asc`:

- App ID: `6474638845`
- iOS version ID: `71b08161-5aaa-4ebf-9721-a732557cbf67`
- iOS en-US localization ID: `1b4ae050-a412-4a9a-bbf5-e58441a1ba91`
- macOS version ID: `e01c93cb-37ea-419f-b755-9073fe58e464`
- macOS en-US localization ID: `b6711156-7077-4092-8b53-d1ccd0ac340d`
- visionOS version ID: `0a7a27a4-d474-4495-84fa-9b58f95c2e91`
- visionOS en-US localization ID: `872137d8-3ad1-4b9c-8355-b3e048e3c0f2`

Dry-run the exact current upload plan:

```sh
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type IPHONE_65 --platform IOS --dry-run
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type IPAD_PRO_3GEN_129 --platform IOS --dry-run
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type DESKTOP --platform MAC_OS --dry-run
asc screenshots upload --app 6474638845 --version 1.2.0 --path app-store-assets/screenshots --device-type APPLE_VISION_PRO --platform VISION_OS --dry-run

asc video-previews upload --version-localization 1b4ae050-a412-4a9a-bbf5-e58441a1ba91 --path app-store-assets/previews/en-US/iphone-65 --device-type IPHONE_65 --dry-run
asc video-previews upload --version-localization 1b4ae050-a412-4a9a-bbf5-e58441a1ba91 --path app-store-assets/previews/en-US/ipad-pro-129 --device-type IPAD_PRO_3GEN_129 --dry-run
asc video-previews upload --version-localization b6711156-7077-4092-8b53-d1ccd0ac340d --path app-store-assets/previews/en-US/macos --device-type DESKTOP --dry-run
asc video-previews upload --version-localization 872137d8-3ad1-4b9c-8355-b3e048e3c0f2 --path app-store-assets/previews/en-US/visionos --device-type APPLE_VISION_PRO --dry-run
```

Remove `--dry-run` when ready to upload. Add `--replace` if the target slot should be cleared first.
