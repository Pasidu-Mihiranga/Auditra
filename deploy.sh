#!/bin/bash

# Auditra Deployment Script for VPS
# Run this script on your VPS server

set -e  # Exit on error

VPS_IP="152.42.240.220"
PROJECT_DIR="/var/www/auditra"
REPO_URL="https://github.com/Pasidu-Mihiranga/Auditra.git"
BRANCH="Pasidu"

echo "🚀 Starting Auditra Deployment..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib nginx git supervisor

# Create project directory
echo "📁 Creating project directory..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Clone or update repository
if [ -d ".git" ]; then
    echo "📥 Updating repository..."
    git fetch origin
    git checkout $BRANCH
    git pull origin $BRANCH
else
    echo "📥 Cloning repository..."
    git clone -b $BRANCH $REPO_URL .
fi

# Set up PostgreSQL
echo "🗄️ Setting up PostgreSQL database..."
sudo -u postgres psql << EOF
-- Create database if not exists
SELECT 'CREATE DATABASE auditra_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'auditra_db')\gexec

-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'auditra_user') THEN
        CREATE USER auditra_user WITH PASSWORD 'auditra_secure_password_123';
    END IF;
END
\$\$;

-- Grant privileges
ALTER ROLE auditra_user SET client_encoding TO 'utf8';
ALTER ROLE auditra_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE auditra_user SET timezone TO 'Asia/Colombo';
GRANT ALL PRIVILEGES ON DATABASE auditra_db TO auditra_user;
EOF

# Set up Python virtual environment
echo "🐍 Setting up Python virtual environment..."
cd $PROJECT_DIR/backend
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# Generate secret key
SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Create .env file
echo "⚙️ Creating .env configuration file..."
cat > .env << EOF
DB_NAME=auditra_db
DB_USER=auditra_user
DB_PASSWORD=auditra_secure_password_123
DB_HOST=localhost
DB_PORT=5432
SECRET_KEY=$SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=$VPS_IP
EOF

echo "⚠️  IMPORTANT: Please edit $PROJECT_DIR/backend/.env to change the database password!"

# Run migrations
echo "🔄 Running database migrations..."
python manage.py makemigrations
python manage.py migrate

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Create admin user (skip if exists)
echo "👤 Creating admin user..."
python manage.py create_admin || echo "Admin user may already exist"

# Set up Gunicorn with Supervisor
echo "🔧 Configuring Gunicorn with Supervisor..."
mkdir -p /var/log/auditra
chown www-data:www-data /var/log/auditra

cat > /etc/supervisor/conf.d/auditra.conf << EOF
[program:auditra]
directory=$PROJECT_DIR/backend
command=$PROJECT_DIR/backend/venv/bin/gunicorn auditra_backend.wsgi:application --bind 127.0.0.1:8000 --workers 3 --timeout 120
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/auditra/gunicorn.log
stderr_logfile=/var/log/auditra/gunicorn_error.log
environment=PATH="$PROJECT_DIR/backend/venv/bin"
EOF

# Configure Nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/auditra << EOF
server {
    listen 80;
    server_name $VPS_IP;

    client_max_body_size 100M;

    location /media/ {
        alias $PROJECT_DIR/backend/media/;
    }

    location /static/ {
        alias $PROJECT_DIR/backend/staticfiles/;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
    }

    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/auditra /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t

# Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Start services
echo "🚀 Starting services..."
systemctl restart nginx
supervisorctl reread
supervisorctl update
supervisorctl start auditra

echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit $PROJECT_DIR/backend/.env and change the database password"
echo "2. Update Flutter app API URL to: http://$VPS_IP/api"
echo "3. Check service status: sudo supervisorctl status auditra"
echo "4. View logs: sudo tail -f /var/log/auditra/gunicorn.log"
echo "5. Test API: curl http://$VPS_IP/api/auth/login/"
echo ""
echo "🔗 API will be available at: http://$VPS_IP/api"

