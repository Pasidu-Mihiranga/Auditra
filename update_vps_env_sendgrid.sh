#!/bin/bash

# Script to update VPS .env file with SendGrid configuration
# Usage: ./update_vps_env_sendgrid.sh

echo "=========================================="
echo "Updating VPS .env file with SendGrid config"
echo "=========================================="

# SSH into VPS and update .env file
ssh root@152.42.240.220 << 'ENDSSH'

cd /var/www/auditra/backend

# Backup existing .env
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Created backup of .env file"

# Check if SENDGRID_API_KEY already exists
if grep -q "SENDGRID_API_KEY" .env; then
    echo "⚠️  SENDGRID_API_KEY already exists in .env"
    echo "Please update it manually or remove the old line first"
else
    # Add SendGrid configuration
    echo "" >> .env
    echo "# SendGrid Email Configuration" >> .env
    echo "SENDGRID_API_KEY=SG.your_sendgrid_api_key_here" >> .env
    echo "DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com" >> .env
    echo "✅ Added SendGrid configuration to .env"
    echo ""
    echo "⚠️  IMPORTANT: You need to replace 'SG.your_sendgrid_api_key_here' with your actual SendGrid API key!"
fi

# Comment out old SMTP settings if they exist
if grep -q "^EMAIL_HOST_USER" .env; then
    sed -i 's/^EMAIL_HOST_USER/#EMAIL_HOST_USER/' .env
    echo "✅ Commented out EMAIL_HOST_USER"
fi

if grep -q "^EMAIL_HOST_PASSWORD" .env; then
    sed -i 's/^EMAIL_HOST_PASSWORD/#EMAIL_HOST_PASSWORD/' .env
    echo "✅ Commented out EMAIL_HOST_PASSWORD"
fi

if grep -q "^EMAIL_PORT" .env; then
    sed -i 's/^EMAIL_PORT/#EMAIL_PORT/' .env
    echo "✅ Commented out EMAIL_PORT"
fi

if grep -q "^EMAIL_USE_TLS" .env; then
    sed -i 's/^EMAIL_USE_TLS/#EMAIL_USE_TLS/' .env
    echo "✅ Commented out EMAIL_USE_TLS"
fi

echo ""
echo "=========================================="
echo "Current .env file contents:"
echo "=========================================="
cat .env | grep -E "(SENDGRID|DEFAULT_FROM_EMAIL|EMAIL_)" || echo "No email-related settings found"
echo ""
echo "✅ .env file updated!"
echo ""
echo "Next steps:"
echo "1. Edit .env file: nano .env"
echo "2. Replace 'SG.your_sendgrid_api_key_here' with your actual SendGrid API key"
echo "3. Run: pip install sendgrid-django==5.3.0"
echo "4. Run: supervisorctl restart auditra"

ENDSSH

echo ""
echo "=========================================="
echo "Script completed!"
echo "=========================================="

