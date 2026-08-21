# Jiterka

A macOS application that records a meeting and turns it into a document you
can actually use: a transcript, with the speakers separated, cleaned up,
summarised and synced.

A prototype, written over six days in November 2025.

## What it does

1. Records the meeting, taking both system audio and the microphone
2. Transcribes it on device, using the Apple Speech framework
3. Works out who said what
4. Cleans up the raw transcript into readable text
5. Produces a summary
6. Syncs the resulting documents so they can be used elsewhere

It handles more than one language.

## Speaker diarization

There are four interchangeable backends, selected in `DiarizationManager`:

| Mode | Where it runs |
|---|---|
| `fluidAudio` | On the device, CoreML |
| `fluidAudioWithFallback` | On the device, falling back to the local server |
| `pythonServer` | Local Flask service using pyannote 3.1, included in `PyannoteDiarization/` |
| `pyannoteCloud` | Hosted pyannote.ai API |

Diarization runs on the device by default. The hosted mode is there for
comparison, and the local pyannote server is included if you would rather
run that.

## What stays on the machine and what does not

Recording, transcription and speaker diarization all run on the machine.
Transcript clean-up and summarisation send the text to a language model over
the network, so the audio stays local while the text does not.

## Running it

Requirements: macOS 26 or later, since transcription uses the current Speech
framework, and Xcode.

Open `Jiterka.xcodeproj` and run. Nothing else is needed for the default
setup.

To use the local pyannote server instead:

```bash
cd PyannoteDiarization
./setup.sh            # needs Python 3.11 or 3.12, creates a venv
export HF_TOKEN=...   # accept the terms for pyannote/speaker-diarization-3.1 first
./start_server.sh     # listens on 127.0.0.1
```

Then set `mode` in `DiarizationManager` to `.pythonServer`.

To use the hosted API, put your pyannote.ai key in `PYANNOTE_API_KEY`.

## Status

A prototype. It works end to end and it is not a product. Every commit in
this repository is mine.
