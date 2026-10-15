#!/usr/bin/env bash
# Prints the CHANGELOG.md section of one version, the body of its GitHub release:
#
#   scripts/release-notes.sh 0.1.0 > notes.md
#
# The section is the text under "## [<version>]" up to the next "## " heading, without the
# heading and without link reference definitions. Exits 1 when it is missing or empty, so a
# release cannot go out without notes.
set -euo pipefail

version="${1:-}"
changelog="${2:-$(dirname "$0")/../CHANGELOG.md}"
if [ -z "$version" ]; then
  echo "usage: $0 <version> [CHANGELOG.md]" >&2
  exit 64
fi

notes="$(awk -v heading="## [$version]" '
  index($0, heading) == 1 { inside = 1; next }
  inside && /^## / { exit }
  inside && !/^\[[^]]+\]: / { print }
' "$changelog" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [ -z "$notes" ]; then
  echo "CHANGELOG.md has no section, or an empty one, for $version." >&2
  exit 1
fi
printf '%s\n' "$notes"
