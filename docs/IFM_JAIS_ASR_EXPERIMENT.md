# IFM Jais-ASR experiment

This is an opt-in experiment. Whisper remains the default and no existing Whisper
files or dependencies are removed.

## Run locally

1. Revoke any IFM API key that was posted in chat, screenshots, source control,
   logs, or any other place where someone else might see it. Create a new key.
2. From the project root, run the app with compile-time flags:

```powershell
flutter run --dart-define=USE_IFM_JAIS_ASR=true --dart-define=IFM_API_KEY=YOUR_NEW_TEST_KEY
```

3. Hold the microphone, speak a short destination command, and release it.
   The app records 16 kHz mono WAV and submits it to
   `https://api.ifm.ai/v1/audio/transcriptions` with model `IFM/Jais-ASR`.
4. To return to Whisper, run normally without either define:

```powershell
flutter run
```

## Important security note

Dart `--dart-define` values are compiled into the client app and are **not a
secure way to store a production API key**. This switch is only for a temporary,
local evaluation build. Do not distribute this build or publish it. For production,
put the IFM request behind a backend endpoint and store the key in the backend's
environment/secrets manager.

## What this experiment does

- Keeps the existing microphone press/release interaction.
- Keeps the existing Whisper implementation intact as the default.
- Sends the finished WAV to IFM only when the opt-in flag is enabled.
- Deletes the temporary audio file after the request finishes.
- Does not print the API key.
- Surfaces HTTP errors as voice-recognition failures.

The API response parser accepts plain text and common JSON transcript fields
(`text`, `transcription`, `transcript`, or `segments`). Verify the actual IFM
response shape with your account. No live API/device test was run as part of
this code change.
