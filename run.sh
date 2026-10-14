#!/bin/bash
# Build on first run; reuse the binary while the source is unchanged.
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p .build/module-cache
if [[ ! -x .build/playback-helper || main.swift -nt .build/playback-helper ]]; then
  xcrun swiftc -module-cache-path .build/module-cache main.swift -o .build/playback-helper
fi
exec .build/playback-helper "$@"
