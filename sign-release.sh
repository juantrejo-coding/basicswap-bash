#!/usr/bin/env bash
# Sign a release of the Whonix installer.
#
#   ./sign-release.sh <number>      e.g. ./sign-release.sh 1  ->  tag installer-v1
#
# Run it in a terminal: gpg asks for the signing key's passphrase. It
#   1. rebuilds install-whonix-basicswap.sh and checks it matches the committed one,
#   2. writes SHA256SUMS for the two scripts and a detached signature SHA256SUMS.asc,
#   3. commits those to the installer branch,
#   4. creates the signed annotated tag installer-v<number>,
# then prints the push command. Nothing is pushed.
set -Eeuo pipefail

SIGNING_KEY=93F4433DCE56353BD7E69D42CBFE4123CF4121FA
SIGNER_NAME="Juan Trejo"
SIGNER_EMAIL="juantrejo_coding@proton.me"
FILES=(install-whonix-basicswap.sh setup-whonix-template.sh)

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ "${1:-}" =~ ^[0-9]+$ ]] || die "Usage: $0 <release number>"
tag="installer-v$1"
cd "$(dirname "${BASH_SOURCE[0]}")"

[[ $(git branch --show-current) == installer ]] || die "Run this on the installer branch."
git rev-parse --verify --quiet "refs/tags/$tag" > /dev/null && die "Tag $tag already exists."
[[ -z $(git status --porcelain) ]] || die "Commit or discard local changes first."

bash make-installer.sh > /dev/null
[[ -z $(git status --porcelain) ]] ||
    die "install-whonix-basicswap.sh is out of date. Commit the regenerated file first."

export GPG_TTY=$(tty)
sha256sum "${FILES[@]}" > SHA256SUMS
rm -f SHA256SUMS.asc
gpg --local-user "$SIGNING_KEY" --armor --detach-sign --output SHA256SUMS.asc SHA256SUMS
gpg --verify SHA256SUMS.asc SHA256SUMS

whonix=$(git rev-parse whonix)
upstream=$(sed -n 's/^HELPER_TAG="\(.*\)"$/\1/p' install-whonix-basicswap.sh)
core=$(sed -n 's/^export BSX_CORE_TAG="\${BSX_CORE_TAG:-\(.*\)}"$/\1/p' <(git show whonix:bsx/shared.sh))

git add SHA256SUMS SHA256SUMS.asc
git -c user.name="$SIGNER_NAME" -c user.email="$SIGNER_EMAIL" \
    commit -q -m "Release $tag: signed checksums"
git -c user.name="$SIGNER_NAME" -c user.email="$SIGNER_EMAIL" \
    tag -s -u "$SIGNING_KEY" -F - "$tag" << EOF
$tag

basicswap-bash $upstream + Whonix patches (whonix branch $whonix)
BasicSwap core: $core

$(cat SHA256SUMS)
EOF
git verify-tag "$tag"

echo
echo "Signed $tag. Push it with:"
echo "  git push github installer $tag"
