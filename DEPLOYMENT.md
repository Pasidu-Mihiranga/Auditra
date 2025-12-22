# Auditra VPS Deployment Guide

This guide will help you deploy the Auditra application to your VPS at `152.42.240.220`.

## Prerequisites

Before starting, ensure your VPS has:
- Ubuntu 20.04+ or similar Linux distribution
- SSH access to the server
- Root or sudo access
- Python 3.9+ installed
- PostgreSQL installed
- Nginx installed (for reverse proxy)
- Domain name (optional, for SSL)

## Quick Deployment Steps

### 1. Connect to Your VPS

```bash
ssh root@152.42.240.220
# Or
ssh your_username@152.42.240.220
```

### 2. Install Required Software

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and pip
sudo apt install python3 python3-pip python3-venv -y

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Install Nginx
sudo apt install nginx -y

# Install Git
sudo apt install git -y

# Install Supervisor (for process management)
sudo apt install supervisor -y
```

### 3. Set Up PostgreSQL Database

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE auditra_db;
CREATE USER auditra_user WITH PASSWORD 'your_secure_password_here';
ALTER ROLE auditra_user SET client_encoding TO 'utf8';
ALTER ROLE auditra_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE auditra_user SET timezone TO 'Asia/Colombo';
GRANT ALL PRIVILEGES ON DATABASE auditra_db TO auditra_user;
\q
```

### 4. Clone Repository and Set Up Backend

```bash
# Create project directory
sudo mkdir -p /var/www/auditra
sudo chown $USER:$USER /var/www/auditra
cd /var/www/auditra

# Clone your repository (use your actual repo URL)
git clone https://github.com/Pasidu-Mihiranga/Auditra.git .

# Or if you want to pull from Pasidu branch
git checkout Pasidu
git pull origin Pasidu

# Navigate to backend
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn  # Add Gunicorn for production

# Create .env file
nano .env
```

Add the following to `.env`:

```env
DB_NAME=auditra_db
DB_USER=auditra_user
DB_PASSWORD=your_secure_password_here
DB_HOST=localhost
DB_PORT=5432
SECRET_KEY=your-very-secret-key-here-generate-with-openssl-rand-hex-32
DEBUG=False
ALLOWED_HOSTS=152.42.240.220,yourdomain.com
```

Generate a secret key:
```bash
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
```

### 5. Configure Django for Production

Edit `backend/auditra_backend/settings.py`:

```python
# Update these settings:
DEBUG = config('DEBUG', default=False, cast=bool)
SECRET_KEY = config('SECRET_KEY')
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='').split(',')

# Add static files configuration
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATIC_URL = '/static/'

# Security settings for production
SECURE_SSL_REDIRECT = False  # Set to True if using HTTPS
SESSION_COOKIE_SECURE = False  # Set to True if using HTTPS
CSRF_COOKIE_SECURE = False  # Set to True if using HTTPS
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
```

### 6. Run Migrations and Collect Static Files

```bash
cd /var/www/auditra/backend
source venv/bin/activate

# Run migrations
python manage.py makemigrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Create admin user
python manage.py create_admin
```

### 7. Set Up Gunicorn

Create `/etc/supervisor/conf.d/auditra.conf`:

```ini
[program:auditra]
directory=/var/www/auditra/backend
command=/var/www/auditra/backend/venv/bin/gunicorn auditra_backend.wsgi:application --bind 127.0.0.1:8000 --workers 3
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/auditra/gunicorn.log
```

Create log directory:
```bash
sudo mkdir -p /var/log/auditra
sudo chown www-data:www-data /var/log/auditra
```

### 8. Configure Nginx

Create `/etc/nginx/sites-available/auditra`:

```nginx
server {
    listen 80;
    server_name 152.42.240.220 yourdomain.com;

    # Maximum upload size (for file uploads)
    client_max_body_size 100M;

    # Media files
    location /media/ {
        alias /var/www/auditra/backend/media/;
    }

    # Static files
    location /static/ {
        alias /var/www/auditra/backend/staticfiles/;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Admin panel
    location /admin/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Root
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/auditra /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 9. Start Supervisor

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start auditra
sudo supervisorctl status
```

### 10. Configure Firewall

```bash
# Allow HTTP, HTTPS, and SSH
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 11. Update Flutter App API URL

In `auditra/lib/services/api_service.dart`, change:

```dart
static const String baseUrl = 'http://152.42.240.220/api';
// Or if using HTTPS with domain:
// static const String baseUrl = 'https://yourdomain.com/api';
```

Then rebuild the Flutter app:
```bash
cd auditra
flutter build apk --release  # For Android
flutter build ios --release  # For iOS
```

## SSL/HTTPS Setup (Optional but Recommended)

### Using Let's Encrypt (Certbot)

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Then update `.env` and `settings.py`:
- Set `SECURE_SSL_REDIRECT = True`
- Set `SESSION_COOKIE_SECURE = True`
- Set `CSRF_COOKIE_SECURE = True`

## Useful Commands

### Check Gunicorn Status
```bash
sudo supervisorctl status auditra
```

### View Logs
```bash
sudo tail -f /var/log/auditra/gunicorn.log
sudo tail -f /var/log/nginx/error.log
```

### Restart Services
```bash
sudo supervisorctl restart auditra
sudo systemctl restart nginx
```

### Update Code
```bash
cd /var/www/auditra
git pull origin Pasidu
cd backend
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo supervisorctl restart auditra
```

## Troubleshooting

### Check if services are running
```bash
sudo systemctl status nginx
sudo supervisorctl status auditra
sudo systemctl status postgresql
```

### Check database connection
```bash
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py dbshell
```

### Check API is accessible
```bash
curl http://152.42.240.220/api/auth/login/
```

## Security Checklist

- [ ] Change default database password
- [ ] Use strong SECRET_KEY
- [ ] Set DEBUG=False
- [ ] Configure ALLOWED_HOSTS properly
- [ ] Set up firewall rules
- [ ] Use HTTPS (recommended)
- [ ] Regular backups of database
- [ ] Keep system and packages updated

