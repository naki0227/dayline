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

The production target declares the audio background mode plus microphone and
speech usage descriptions.

## Transcription boundary

`SpeechTranscribing` isolates speech analysis from capture orchestration. On iOS
26 or later, `AppleSpeechFileTranscriber` requests speech authorization, resolves
an equivalent supported locale, installs required on-device assets, and streams
progressive `SpeechTranscriber` results from each completed audio chunk. Capture
continues when authorization, assets, locale support, audio decoding, or analysis
fails; callers receive only a finite, content-free `TranscriptionFailure`.

`TranscriptBuffer` keeps volatile hypotheses separate from finalized evidence,
rejects blank text, and ignores duplicate final segments. Only finalized segments
may be mapped into a `ContextEvent`. `TranscriptEventMapper` performs that mapping
through the versioned `ContextCoreKit` DTO, assigns the event to the configured
IANA timezone day, and records only duration, locale, and finalization metadata.
Rust persistence remains a separate composition responsibility.

## Testing

Package tests use deterministic recorder and transcriber fakes for success,
permission failure, manual rotation, interruption/resume, volatile/final segment
handling, duplicate rejection, and ContextEvent mapping. The XCUITest launches with
`--ui-testing`; the composition root then injects a fake recorder, so CI never sees
a microphone permission dialog or writes a real recording.
