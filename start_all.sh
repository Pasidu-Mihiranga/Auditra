#!/bin/bash

echo "========================================"
echo "Starting Auditra - Backend + Web App"
echo "========================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WEB_APP_PATH="$SCRIPT_DIR/auditra web app/index.html"

echo "Step 1: Opening Web App in Browser..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$WEB_APP_PATH" &
elif [[ "$OSTYPE" == "darwin"* ]]; then
    open "$WEB_APP_PATH" &
else
    echo "Unsupported OS. Please open manually: $WEB_APP_PATH"
fi

sleep 2

echo ""
echo "Step 2: Starting Backend Server..."
echo ""

cd backend

echo "Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    exit 1
fi

python3 --version

echo ""
echo "Activating virtual environment (if exists)..."
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "Virtual environment activated."
else
    echo "No virtual environment found. Using system Python."
fi

echo ""
echo "Running database migrations..."
python3 manage.py migrate

echo ""
echo "========================================"
echo "Starting Django Development Server..."
echo "========================================"
echo ""
echo "Backend: http://localhost:8000"
echo "API: http://localhost:8000/api/"
echo "Web App: Should be open in your browser"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python3 manage.py runserver

