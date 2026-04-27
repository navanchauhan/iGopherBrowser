#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(dirname "$SCRIPT_DIR")
cd "$REPOSITORY_ROOT"

echo "Xcode Cloud post-clone setup"
echo "Repository root: $(pwd)"
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
