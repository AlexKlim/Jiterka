#!/bin/bash

source venv/bin/activate

# Set SSL certificate path to use certifi's bundle: MAC OS problem (can be)
export SSL_CERT_FILE=$(python -c "import certifi; print(certifi.where())")

if [ -z "$HF_TOKEN" ]; then
    echo "⚠️  Warning: HF_TOKEN environment variable is not set"
    echo "   Set it with: export HF_TOKEN='your_token_here'"
    echo ""
fi

python diarization_server.py
