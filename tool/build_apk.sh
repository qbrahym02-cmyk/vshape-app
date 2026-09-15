#!/usr/bin/env bash
# Build a signed release APK and copy it to ./release/
# Usage:  ./tool/build_apk.sh [--split-per-abi]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter is not on PATH." >&2
  echo "Install Flutter 3.47+ then re-run: https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

if [ ! -f android/local.properties ]; then
  if [ -n "${ANDROID_HOME:-}" ] && [ -n "${FLUTTER_ROOT:-}" ]; then
    printf 'sdk.dir=%s\nflutter.sdk=%s\n' "$ANDROID_HOME" "$FLUTTER_ROOT" > android/local.properties
    echo "Created android/local.properties"
  else
    echo "WARNING: android/local.properties missing and ANDROID_HOME/FLUTTER_ROOT are not set." >&2
  fi
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter test"
flutter test

echo "==> flutter build apk --release $*"
flutter build apk --release "$@"

mkdir -p release
VER="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
NAME="${VER%%+*}"
CODE="${VER##*+}"
[ "$NAME" = "$CODE" ] && CODE=1

cp build/app/outputs/flutter-apk/app-release.apk "release/V-System-universal.apk"
printf '{"versionName":"%s","versionCode":%s}\n' "$NAME" "$CODE" > release/version.json
( cd release && sha256sum *.apk > checksums.sha256 )

echo
echo "DONE:"
ls -lh release/
echo
echo "Next: git tag v${NAME}+${CODE} && git push origin --tags   (CI will publish the Release)"
