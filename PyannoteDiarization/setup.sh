#!/bin/bash

echo "🚀 Setting up Pyannote Diarization Server..."
echo ""

# Python 3.11 or 3.12 - required for torch 2.1.2
PYTHON_CMD=""

if command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
    echo "✅ Found Python 3.11: $(python3.11 --version)"
elif command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
    echo "✅ Found Python 3.12: $(python3.12 --version)"
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    if [[ "$PYTHON_VERSION" == "3.11" ]] || [[ "$PYTHON_VERSION" == "3.12" ]]; then
        PYTHON_CMD="python3"
        echo "✅ Found Python $PYTHON_VERSION"
    else
        echo "❌ Python 3.11 or 3.12 required (found $PYTHON_VERSION)"
        echo ""
        echo "Install Python 3.11 using Homebrew:"
        echo "  brew install python@3.11"
        echo ""
        echo "Or use pyenv:"
        echo "  pyenv install 3.11.9"
        echo "  pyenv local 3.11.9"
        exit 1
    fi
else
    echo "❌ Python 3 is not installed"
    echo ""
    echo "Install Python 3.11 using Homebrew:"
    echo "  brew install python@3.11"
    exit 1
fi

if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment with $PYTHON_CMD..."
    $PYTHON_CMD -m venv venv
else
    echo "✅ Virtual environment already exists"
fi

echo "🔌 Activating virtual environment..."
source venv/bin/activate

echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Get Hugging Face token from: https://huggingface.co/settings/tokens"
echo "2. Accept terms at: https://huggingface.co/pyannote/speaker-diarization-3.1"
echo "3. Export token: export HF_TOKEN='your_token_here'"
echo "4. Run server: python diarization_server.py"
echo ""
