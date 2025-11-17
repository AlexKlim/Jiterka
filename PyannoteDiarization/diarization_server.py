#!/usr/bin/env python3

import os
import json
import token
import tempfile
from flask import Flask, request, jsonify
from pyannote.audio import Pipeline
import torch
import torchaudio
from pydub import AudioSegment

app = Flask(__name__)

pipeline = None


def load_pipeline():
    global pipeline

    if pipeline is not None:
        return pipeline

    hf_token = os.environ.get('HF_TOKEN')

    try:
        print(f"Loading pipeline with token: {hf_token}")
        pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=hf_token
        )

        if torch.cuda.is_available():
            pipeline = pipeline.to(torch.device("cuda"))
            print("✅ Using GPU for diarization")
        elif torch.backends.mps.is_available():
            pipeline = pipeline.to(torch.device("mps"))
            print("✅ Using Apple Silicon GPU for diarization")
        else:
            print("✅ Using CPU for diarization")

        return pipeline
    except Exception as e:
        print(f"❌ Failed to load pipeline: {e}")
        raise


def convert_to_wav(audio_path):
    if audio_path.lower().endswith('.wav'):
        return audio_path, None

    print(f"🔄 Converting {os.path.basename(audio_path)} to WAV...")

    try:
        audio = AudioSegment.from_file(audio_path)

        temp_wav = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
        temp_wav_path = temp_wav.name
        temp_wav.close()

        audio.export(temp_wav_path, format='wav')

        print(f"✅ Converted to WAV: {temp_wav_path}")
        return temp_wav_path, temp_wav_path  # Return path and cleanup path
    except Exception as e:
        print(f"❌ Audio conversion failed: {e}")
        raise


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "service": "pyannote-diarization"})


@app.route('/diarize', methods=['POST'])
def diarize():
    """
    Request:
    {
        "audio_path": "/path/to/audio.m4a",
        "num_speakers": null  # optional: specify expected number of speakers
    }

    Response JSON:
    {
        "segments": [
            {
                "speaker": "SPEAKER_00",
                "start": 0.5,
                "end": 2.3
            },
            ...
        ],
        "num_speakers": 2
    }
    """
    try:
        data = request.get_json()

        if not data or 'audio_path' not in data:
            return jsonify({"error": "Missing audio_path parameter"}), 400

        audio_path = data['audio_path']
        num_speakers = data.get('num_speakers')

        if not os.path.exists(audio_path):
            return jsonify({"error": f"Audio file not found: {audio_path}"}), 404

        print(f"🎯 Processing: {audio_path}")

        wav_path, temp_path = convert_to_wav(audio_path)

        try:
            pipe = load_pipeline()
            kwargs = {}

            if num_speakers is not None:
                kwargs['num_speakers'] = num_speakers

            try:
                diarization = pipe(wav_path, **kwargs)
            except Exception as e:
                print(f"⚠️ Direct path failed, loading audio manually: {e}")
                waveform, sample_rate = torchaudio.load(wav_path)
                diarization = pipe({"waveform": waveform, "sample_rate": sample_rate}, **kwargs)
        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)
                print(f"🗑️ Cleaned up temp file: {temp_path}")

        segments = []
        speakers_set = set()

        for turn, _, speaker in diarization.itertracks(yield_label=True):
            segments.append({
                "speaker": speaker,
                "start": float(turn.start),
                "end": float(turn.end)
            })
            speakers_set.add(speaker)

        result = {
            "segments": segments,
            "num_speakers": len(speakers_set)
        }

        print(f"✅ Detected {len(speakers_set)} speakers in {len(segments)} segments")

        return jsonify(result)

    except Exception as e:
        print(f"❌ Diarization error: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    print("🚀 Starting Pyannote Diarization Server...")

    try:
        load_pipeline()
        print("✅ Pipeline loaded successfully")
    except Exception as e:
        print(f"⚠️ Warning: Could not pre-load pipeline: {e}")

    app.run(host='127.0.0.1', port=5555, debug=False)
