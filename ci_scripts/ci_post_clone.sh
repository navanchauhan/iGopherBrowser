#!/bin/sh
set -eu

echo "Xcode Cloud post-clone setup"
echo "Repository: ${CI_WORKSPACE:-$(pwd)}"
echo "Branch: ${CI_BRANCH:-unknown}"
echo "Workflow: ${CI_WORKFLOW:-unknown}"
echo "Build number: ${CI_BUILD_NUMBER:-unknown}"

xcodebuild -version
swift --version

if [ ! -d "iGopherBrowser.xcodeproj" ]; then
  echo "error: iGopherBrowser.xcodeproj was not found at the repository root"
  exit 1
fi

echo "Resolving Swift package dependencies"
xcodebuild \
  -resolvePackageDependencies \
  -project iGopherBrowser.xcodeproj \
  -scheme iGopherBrowser

