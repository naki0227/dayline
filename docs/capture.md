# Capture

`ContextCaptureKit` separates orchestration from AVFAudio. `CaptureCoordinator`
owns the state machine and accepts any `AudioRecording`; `AVAudioRecorderAdapter`
is the iOS implementation.

## State invariants

- Daily and audio-source state are independent.
- An audio interruption never stops Daily capture.
- A resumable interruption starts a new chunk instead of appending to a possibly
  incomplete audio container.
- Start failure resets Daily to stopped and exposes only a content-free failure.
- Stop is idempotent outside the running state.
- Chunk rotation preserves Daily running state.

## Audio format and storage

Passive capture writes AAC-LC mono at 16 kHz and 32 kbps. A coordinator task
rotates chunks every five minutes. Files are placed below
`Application Support/audio/YYYY-MM-DD/<uuid>.m4a`. Raw audio remains local and is
not part of CloudKit synchronization.

The production target declares the audio background mode and microphone usage
description. Speech permission is declared for the next transcription adapter.

## Testing

Package tests use a deterministic recorder fake for success, permission failure,
manual rotation, and interruption/resume. The XCUITest launches with
`--ui-testing`; the composition root then injects a fake recorder, so CI never sees
a microphone permission dialog or writes a real recording.
