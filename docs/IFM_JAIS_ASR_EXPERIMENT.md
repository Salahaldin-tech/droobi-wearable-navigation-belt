# IFM Jais-ASR speech recognition

Jais-ASR is the primary speech-to-text provider in this branch. The app records
16 kHz mono WAV audio and sends it to IFM's
`https://api.ifm.ai/v1/audio/transcriptions` endpoint using model
`IFM/Jais-ASR`.

## Local testing

1. Revoke any IFM API key previously shared in chat, screenshots, logs, or source
   control, then create a new key.
2. From the project root, run:

```powershell
flutter run --dart-define=IFM_API_KEY=YOUR_NEW_TEST_KEY
```

3. Choose Arabic or English in the app's microphone language setting. The service
   sends `language=ar` or `language=en` with the transcription request.
4. Hold the microphone, speak a destination, then release it. The transcript is
   trimmed and trailing sentence punctuation is removed before it is passed to
   destination search.
5. This branch no longer includes Whisper or its model download.

## Security

Dart `--dart-define` values are compiled into the client app and are **not secure
storage**. This direct API configuration is only for local testing. Do not
distribute a build containing the key. For production, route the request through
a backend and store the key in a backend secret/environment variable.

## Verification status

The repository changes were not run on a physical device and the IFM API request
was not verified with an actual key during implementation. Confirm the actual
response shape and whether the IFM endpoint accepts the optional `language`
field when testing.
