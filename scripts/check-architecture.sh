#!/usr/bin/env bash
set -euo pipefail

status=0

reject_pattern() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if rg --line-number "$pattern" "$path"; then
    echo "architecture error: $message" >&2
    status=1
  fi
}

reject_pattern \
  rust/crates/context-domain \
  '(^|[^[:alnum:]_])(axum|sqlx|rusqlite|uniffi)([^[:alnum:]_]|$)' \
  'context-domain must remain independent of frameworks, persistence, and FFI'

reject_pattern \
  packages/ContextCoreKit/Sources \
  '^import (FoundationModels|SwiftUI|SwiftData|CloudKit|AVFAudio|Speech)$' \
  'ContextCoreKit must not import UI, model runtime, capture, or persistence frameworks'

reject_pattern \
  packages/ContextCoreKit \
  'AppleIntelligenceKit' \
  'ContextCoreKit must not depend on AppleIntelligenceKit'

reject_pattern \
  packages/AppleIntelligenceKit/Sources \
  '^import (SwiftUI|SwiftData|CloudKit|AVFAudio|Speech)$' \
  'AppleIntelligenceKit must not own UI, capture, or persistence'

reject_pattern \
  packages/ContextCaptureKit/Sources \
  '^import (FoundationModels|SwiftUI|SwiftData|CloudKit|ContextCoreFFIKit)$' \
  'ContextCaptureKit must not own model runtime, UI, synchronization, or FFI'

exit "$status"
