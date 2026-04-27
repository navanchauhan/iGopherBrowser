#!/bin/sh
set -eu

echo "Xcode Cloud pre-xcodebuild checks"
echo "Action: ${CI_XCODEBUILD_ACTION:-unknown}"

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  echo "Using Xcode Cloud build number ${CI_BUILD_NUMBER}"
  xcrun agvtool new-version -all "${CI_BUILD_NUMBER}"
fi

echo "Project versions"
xcodebuild \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowser \
  -showBuildSettings \
  | grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|MACOSX_DEPLOYMENT_TARGET|XROS_DEPLOYMENT_TARGET" \
  | sort -u

