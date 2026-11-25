#!/usr/bin/env bash
# Build install-whonix-basicswap.sh from the whonix branch of the fork.
# Usage: make-installer.sh [fork_dir] [upstream_tag]
set -Eeuo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Default: this repo when it has the whonix branch (the installer branch of the GitHub
# fork), otherwise a separate checkout next to this directory
if git -C "$here" rev-parse --verify --quiet whonix > /dev/null 2>&1; then
    fork=${1:-$here}
else
    fork=${1:-$here/../basicswap-bash-whonix}
fi
tag=${2:-v0.19.1}
out=$here/install-whonix-basicswap.sh

commit=$(git -C "$fork" rev-parse "$tag^{commit}")
tree=$(git -C "$fork" rev-parse 'whonix^{tree}')
git -C "$fork" merge-base --is-ancestor "$commit" whonix ||
    { echo "whonix branch isn't based on $tag" >&2; exit 1; }

sed -e "s/@HELPER_TAG@/$tag/g" \
    -e "s/@HELPER_COMMIT@/$commit/g" \
    -e "s/@PATCHED_TREE@/$tree/g" \
    "$here/installer.template.sh" > "$out"
git -C "$fork" format-patch --stdout --no-signature "$commit..whonix" >> "$out"
echo __WHONIX_PATCHES__ >> "$out"
chmod 700 "$out"
bash -n "$out"
echo "$out: $tag ($commit) -> tree $tree"
