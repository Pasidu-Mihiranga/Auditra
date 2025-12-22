# Update VPS .env File with Email Configuration

This guide will help you update the `.env` file on your VPS server with the email configuration.

## Option 1: Using the Update Script (Recommended)

### Step 1: Copy the script to your VPS

From your local machine, copy the script to the VPS:

```bash
scp update_vps_env.sh root@152.42.240.220:/tmp/
```

### Step 2: SSH into your VPS

```bash
ssh root@152.42.240.220
```

### Step 3: Run the update script

```bash
chmod +x /tmp/update_vps_env.sh
/tmp/update_vps_env.sh
```

The script will:
- Backup your existing `.env` file
- Add or update email configuration
- Restart the Django service

## Option 2: Manual Update via SSH

### Step 1: SSH into your VPS

```bash
ssh root@152.42.240.220
```

### Step 2: Navigate to the project directory

```bash
cd /var/www/auditra/backend
```

### Step 3: Edit the .env file

```bash
nano .env
```

### Step 4: Add these lines at the end of the file

```env
# Email Configuration (Gmail SMTP)
EMAIL_HOST_USER=auditra.auditing.erp@gmail.com
EMAIL_HOST_PASSWORD=idbg rzmf kkjg egsz
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
```

### Step 5: Save and exit

- Press `Ctrl + X`
- Press `Y` to confirm
- Press `Enter` to save

### Step 6: Restart the Django service

```bash
supervisorctl restart auditra
```

### Step 7: Verify the service is running

```bash
supervisorctl status auditra
```

You should see `RUNNING` status.

## Option 3: Direct Command Update

Run these commands directly on your VPS:

```bash
# Navigate to backend directory
cd /var/www/auditra/backend

# Backup .env file
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# Add email configuration (if not already present)
if ! grep -q "EMAIL_HOST_USER" .env; then
    cat >> .env << EOF

# Email Configuration (Gmail SMTP)
EMAIL_HOST_USER=auditra.auditing.erp@gmail.com
EMAIL_HOST_PASSWORD=idbg rzmf kkjg egsz
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
EOF
fi

# Restart service
supervisorctl restart auditra

# Check status
supervisorctl status auditra
```

## Verify Email Configuration

After updating, you can test if emails work by:

1. Creating a new project with a new client/agent email
2. Check the Django logs for email sending:
   ```bash
   tail -f /var/log/auditra/gunicorn.log
   ```

## Troubleshooting

### If the service doesn't restart:

```bash
# Check supervisor status
supervisorctl status

# Check logs
tail -f /var/log/auditra/gunicorn_error.log

# Manually restart
supervisorctl restart auditra
```

### If emails don't send:

1. Verify the app password is correct (no extra spaces)
2. Check Django logs for email errors
3. Ensure Gmail 2FA is enabled and app password is valid
4. Test email configuration:
   ```bash
   cd /var/www/auditra/backend
   source venv/bin/activate
   python manage.py shell
   ```
   Then in Python shell:
   ```python
   from django.core.mail import send_mail
   from django.conf import settings
   send_mail('Test', 'Test message', settings.DEFAULT_FROM_EMAIL, ['your-email@example.com'])
   ```

## Security Notes

- The `.env` file contains sensitive information
- Never commit it to Git
- Keep backups of your `.env` file
- The app password shown here should be kept secure

