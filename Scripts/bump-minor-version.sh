#!/bin/sh
set -eu

PLIST_PATH="${1:-Info.plist}"
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH")

IFS=.
set -- $CURRENT_VERSION
unset IFS

MAJOR="${1:-0}"
MINOR="${2:-0}"
PATCH="${3:-0}"

case "$MAJOR:$MINOR:$PATCH" in
  *[!0-9:]*)
    echo "Unsupported version format: $CURRENT_VERSION" >&2
    exit 1
    ;;
esac

NEXT_VERSION="$MAJOR.$((MINOR + 1)).0"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEXT_VERSION" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_VERSION" "$PLIST_PATH"

echo "$NEXT_VERSION"
