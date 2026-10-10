#!/usr/bin/env bash
set -euo pipefail
# Install a pinned toolchain in build scratch space, never ship it as public assets.
SDK_DIR="${TMPDIR:-/tmp}/medideliver-flutter-3.44.2"
if [ ! -x "$SDK_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch 3.44.2 https://github.com/flutter/flutter.git "$SDK_DIR"
fi
test "$(git -C "$SDK_DIR" rev-parse HEAD)" = c9a6c484230f8b5e408ec57be1ef71dee1e77020
export PATH="$SDK_DIR/bin:$PATH"
node scripts/build_config.js
flutter config --no-analytics
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --no-web-resources-cdn --dart-define-from-file=config/build.json
rm -f config/build.json
