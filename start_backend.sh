#!/bin/bash
# Start Django backend on network interface for phone access

cd /Users/geemalfernando/Documents/projects/Auditra/backend

# Activate virtual environment
source venv/bin/activate

# Get current IP
CURRENT_IP=$(ifconfig | grep -A 5 "en0" | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

echo "🚀 Starting Django backend..."
echo "📱 Your IP: $CURRENT_IP"
echo "🌐 Backend will be accessible at: http://$CURRENT_IP:8000"
echo ""
echo "⚠️  Make sure to update api_service.dart with this IP:"
echo "   static const String baseUrl = 'http://$CURRENT_IP:8000/api';"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start server on 0.0.0.0 (accessible from network)
python manage.py runserver 0.0.0.0:8000
