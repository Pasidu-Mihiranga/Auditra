#!/bin/bash

echo "========================================"
echo "Starting Auditra Backend Server"
echo "========================================"
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
echo "Backend will be available at: http://localhost:8000"
echo "API endpoints: http://localhost:8000/api/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python3 manage.py runserver

