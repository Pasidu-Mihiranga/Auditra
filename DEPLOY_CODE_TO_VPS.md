# Deploy Code Changes to VPS

This guide will help you deploy all your code changes (not just .env) to the VPS.

## Quick Method: Automated Script

### Step 1: Commit and Push Your Changes

First, commit all your changes to git:

```bash
# Add all changes
git add .

# Commit with a descriptive message
git commit -m "Add auto-create client/agent accounts with email notifications"

# Push to the Pasidu branch
git push origin Pasidu
```

### Step 2: Run the Deployment Script

```bash
# Make script executable (on Linux/Mac)
chmod +x deploy_code_to_vps.sh

# Run the script
./deploy_code_to_vps.sh
```

The script will:
1. Pull latest code from git on VPS
2. Run database migrations
3. Collect static files
4. Restart Django service
5. Verify everything is running

## Manual Method: Step by Step

If you prefer to do it manually:

### Step 1: Commit and Push (Local Machine)

```bash
git add .
git commit -m "Add auto-create client/agent accounts with email notifications"
git push origin Pasidu
```

### Step 2: Update Code on VPS

```bash
ssh root@152.42.240.220
cd /var/www/auditra
git fetch origin
git checkout Pasidu
git pull origin Pasidu
```

### Step 3: Run Migrations

```bash
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py migrate
```

### Step 4: Collect Static Files

```bash
python manage.py collectstatic --noinput
```

### Step 5: Restart Service

```bash
supervisorctl restart auditra
```

### Step 6: Verify

```bash
supervisorctl status auditra
```

## Files That Need to Be Updated

### Backend Files:
- ✅ `backend/authentication/services.py` (NEW)
- ✅ `backend/auditra_backend/settings.py` (MODIFIED)
- ✅ `backend/authentication/models.py` (MODIFIED)
- ✅ `backend/authentication/migrations/0002_userrole_password_changed.py` (NEW)
- ✅ `backend/projects/utils.py` (NEW)
- ✅ `backend/projects/serializers.py` (MODIFIED)
- ✅ `backend/projects/views.py` (MODIFIED)
- ✅ `backend/authentication/views.py` (MODIFIED)
- ✅ `backend/authentication/serializers.py` (MODIFIED)
- ✅ `backend/authentication/urls.py` (MODIFIED)

### Frontend Files:
- ✅ `auditra/lib/services/api_service.dart` (MODIFIED)
- ✅ `auditra/lib/screens/change_password_screen.dart` (NEW)
- ✅ `auditra/lib/screens/login_screen.dart` (MODIFIED)

## Important Notes

1. **Database Migration**: The new migration (`0002_userrole_password_changed.py`) must be run on VPS
2. **Static Files**: Django static files need to be collected after code changes
3. **Service Restart**: Django service must be restarted to load new code
4. **.env File**: Already updated separately (email configuration)

## Troubleshooting

### If git pull fails:
```bash
# Check current branch
git branch

# If not on Pasidu branch
git checkout Pasidu

# Pull again
git pull origin Pasidu
```

### If migrations fail:
```bash
# Check migration status
python manage.py showmigrations

# Run specific migration
python manage.py migrate authentication 0002
```

### If service won't restart:
```bash
# Check logs
tail -f /var/log/auditra/gunicorn_error.log

# Try restarting supervisor
supervisorctl reread
supervisorctl update
supervisorctl restart auditra
```

### Verify All Files Are Updated:

```bash
# Check if new files exist
ls -la /var/www/auditra/backend/authentication/services.py
ls -la /var/www/auditra/backend/projects/utils.py
ls -la /var/www/auditra/backend/authentication/migrations/0002_userrole_password_changed.py

# Check if migration was applied
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py showmigrations authentication
```

You should see `[X] 0002_userrole_password_changed` if migration was applied.

