#!/bin/bash

echo "========================================"
echo "Opening Auditra Web App"
echo "========================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WEB_APP_PATH="$SCRIPT_DIR/auditra web app/index.html"

if [ ! -f "$WEB_APP_PATH" ]; then
    echo "ERROR: index.html not found at: $WEB_APP_PATH"
    exit 1
fi

echo "Opening index.html in default browser..."
echo "Path: $WEB_APP_PATH"
echo ""

# Detect OS and open accordingly
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$WEB_APP_PATH"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    open "$WEB_APP_PATH"
else
    echo "Unsupported OS. Please open manually: $WEB_APP_PATH"
    exit 1
fi

echo "Web app opened in browser!"
echo ""
echo "Make sure the backend server is running at http://localhost:8000"
echo ""

