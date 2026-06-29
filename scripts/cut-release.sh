#!/usr/bin/env bash
#
# Cut a Paperweight release and update the Homebrew cask so users can
# `brew install --cask harshil-varia/paperweight/paperweight`.
#
# Usage: scripts/cut-release.sh <version>     e.g. scripts/cut-release.sh 0.1.1
#
# Prerequisites: gh authenticated; the tap repo Harshil-varia/homebrew-paperweight
# exists (created once, by hand or `gh repo create`).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: cut-release.sh <version>}"
TAG="v${VERSION}"
REPO="Harshil-varia/paperweight"
TAP="Harshil-varia/homebrew-paperweight"
DMG="build/Release/Paperweight.dmg"

echo "==> Setting version ${VERSION}"
/usr/bin/sed -i '' "s/CFBundleShortVersionString: \".*\"/CFBundleShortVersionString: \"${VERSION}\"/" project.yml
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Sources/App/Info.plist

echo "==> Building release DMG"
make release >/dev/null
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "    sha256 ${SHA}"

echo "==> Publishing GitHub release ${TAG}"
if gh release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
  gh release upload "${TAG}" "${DMG}" --repo "${REPO}" --clobber
else
  gh release create "${TAG}" "${DMG}" --repo "${REPO}" \
    --title "Paperweight ${VERSION}" \
    --notes "Paperweight ${VERSION} — menu-bar paper-texture overlay."
fi

echo "==> Updating cask in ${TAP}"
TMP="$(mktemp -d)"
gh repo clone "${TAP}" "${TMP}/tap" -- -q
mkdir -p "${TMP}/tap/Casks"
sed -e "s/version \".*\"/version \"${VERSION}\"/" \
    -e "s/sha256 \".*\"/sha256 \"${SHA}\"/" \
    packaging/homebrew/paperweight.rb > "${TMP}/tap/Casks/paperweight.rb"
git -C "${TMP}/tap" add Casks/paperweight.rb
git -C "${TMP}/tap" commit -q -m "paperweight ${VERSION}" || echo "    (cask unchanged)"
git -C "${TMP}/tap" push -q
rm -rf "${TMP}"

echo "Done. Install with:"
echo "  brew install --cask ${TAP}/paperweight"
