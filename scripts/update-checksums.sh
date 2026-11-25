#!/usr/bin/env bash
# Rebuild docs/SHA256SUMS and the repository SHA256SUMS from the working tree.
# The repository manifest lists every tracked or untracked, non-ignored file
# except itself. The site manifest lists every file under docs except itself.
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$ROOT"

tmp_docs=$(mktemp)
tmp_root=$(mktemp)
cleanup() { rm -f -- "$tmp_docs" "$tmp_root"; }
trap cleanup EXIT

(
    cd docs
    find . -type f ! -name SHA256SUMS -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 sha256sum
) > "$tmp_docs"
mv -- "$tmp_docs" docs/SHA256SUMS

git ls-files -co --exclude-standard -z \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' path; do
        [[ "$path" == SHA256SUMS ]] && continue
        sha256sum -- "$path"
    done > "$tmp_root"
mv -- "$tmp_root" SHA256SUMS

printf 'Updated SHA256SUMS and docs/SHA256SUMS\n'
