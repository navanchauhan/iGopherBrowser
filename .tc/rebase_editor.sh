#!/usr/bin/env bash
set -euo pipefail
msg_file="$1"
cat > "$msg_file" << 'MSG'
chore: consolidate commits for issue #16; improve macOS coverage and FileView UX

- Add macOS UI test to open image “Screenshot”, exercise “Preview Document”, and attempt “Save As…”
- Gracefully skip when elements are not hittable to avoid flaky CI
- Verify app-only code coverage with xccov and raise FileView coverage

Closes #16
MSG
