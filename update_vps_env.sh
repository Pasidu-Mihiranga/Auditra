#!/bin/bash

# Script to update .env file on VPS with email configuration
# Run this script on your VPS server: ssh root@152.42.240.220

set -e

PROJECT_DIR="/var/www/auditra"
ENV_FILE="$PROJECT_DIR/backend/.env"

echo "📧 Updating .env file with email configuration..."

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    echo "Please ensure the backend is set up first."
    exit 1
fi

# Backup existing .env file
cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created"

# Check if email configuration already exists
if grep -q "EMAIL_HOST_USER" "$ENV_FILE"; then
    echo "⚠️  Email configuration already exists. Updating..."
    # Remove existing email configuration lines
    sed -i '/^# Email Configuration/d' "$ENV_FILE"
    sed -i '/^EMAIL_HOST_USER/d' "$ENV_FILE"
    sed -i '/^EMAIL_HOST_PASSWORD/d' "$ENV_FILE"
    sed -i '/^DEFAULT_FROM_EMAIL/d' "$ENV_FILE"
fi

# Add email configuration
cat >> "$ENV_FILE" << EOF

# Email Configuration (Gmail SMTP)
EMAIL_HOST_USER=auditra.auditing.erp@gmail.com
EMAIL_HOST_PASSWORD=idbg rzmf kkjg egsz
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
EOF

echo "✅ Email configuration added to .env file"
echo ""
echo "📋 Updated .env file location: $ENV_FILE"
echo ""
echo "🔄 Restarting services to apply changes..."

# Restart Gunicorn to apply new environment variables
supervisorctl restart auditra

echo "✅ Services restarted"
echo ""
echo "📧 Email configuration complete!"
echo "The system will now send emails when creating client/agent accounts."

