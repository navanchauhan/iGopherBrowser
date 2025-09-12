#!/usr/bin/env bash
set -euo pipefail
file="$1"
awk 'BEGIN{c=0} {
  if ($0 ~ /Closes #16/) {
    c++;
    if (c==1) sub(/^pick /, "reword "); else sub(/^pick /, "squash ");
  }
  print
}' "$file" > "$file.tmp"
mv "$file.tmp" "$file"
