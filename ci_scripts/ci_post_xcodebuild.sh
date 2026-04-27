#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(dirname "$SCRIPT_DIR")
cd "$REPOSITORY_ROOT"

echo "Xcode Cloud post-xcodebuild summary"
echo "Action: ${CI_XCODEBUILD_ACTION:-unknown}"
echo "Result bundle: ${CI_RESULT_BUNDLE_PATH:-unavailable}"
echo "Archive path: ${CI_ARCHIVE_PATH:-unavailable}"
echo "Product path: ${CI_PRODUCT_PATH:-unavailable}"

if [ -n "${CI_RESULT_BUNDLE_PATH:-}" ] && [ -e "${CI_RESULT_BUNDLE_PATH}" ]; then
  echo "Result bundle exists"
fi
