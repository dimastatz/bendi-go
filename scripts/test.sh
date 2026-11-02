#!/usr/bin/env bash
# Runs every spec in tests/ with the luau CLI, then enforces line coverage on src/core.
set -euo pipefail

cd "$(dirname "$0")/.."

specs=()
while IFS= read -r spec; do
	specs+=("$spec")
done < <(find tests -name '*.spec.luau' | sort)

if [ ${#specs[@]} -eq 0 ]; then
	echo "No specs found in tests/" >&2
	exit 1
fi

rm -f coverage.out
luau --coverage "${specs[@]}"
python3 scripts/coverage.py coverage.out
