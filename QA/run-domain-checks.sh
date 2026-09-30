#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
audit_dir="$(mktemp -d "${TMPDIR:-/tmp}/yutori-checks.XXXXXX")"
trap 'rm -rf "$audit_dir"' EXIT
for source in StudySessionStore StudyStopwatch StudyStreak BowlCatalog CourseStore; do
    cp "$repo_dir/Yutori/$source.swift" "$audit_dir/"
done
cp "$repo_dir/QA/DomainChecks.swift" "$audit_dir/main.swift"
xcrun swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -module-cache-path "$audit_dir/cache" "$audit_dir/"*.swift -o "$audit_dir/checks"
"$audit_dir/checks"
