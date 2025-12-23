# Update VPS .env File with SendGrid Configuration

Since SSH connection might timeout, here are **two methods** to update your VPS .env file:

## Method 1: Manual Update (Recommended)

### Step 1: Connect to VPS
```bash
ssh root@152.42.240.220
```

### Step 2: Navigate to backend folder
```bash
cd /var/www/auditra/backend
```

### Step 3: Backup current .env
```bash
cp .env .env.backup
```

### Step 4: Edit .env file
```bash
nano .env
```

### Step 5: Add these lines at the end of the file
```env
# SendGrid Email Configuration
SENDGRID_API_KEY=SG.your_actual_sendgrid_api_key_here
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
```

**Important:** Replace `SG.your_actual_sendgrid_api_key_here` with your real SendGrid API key!

### Step 6: Comment out old SMTP settings (if they exist)
Find these lines and add `#` at the beginning:
```env
# EMAIL_HOST_USER=auditra.auditing.erp@gmail.com
# EMAIL_HOST_PASSWORD=your_app_password
# EMAIL_PORT=587
# EMAIL_USE_TLS=True
```

### Step 7: Save and exit
- Press `Ctrl + X`
- Press `Y` to confirm
- Press `Enter` to save

### Step 8: Verify the changes
```bash
cat .env | grep -E "(SENDGRID|DEFAULT_FROM_EMAIL)"
```

You should see:
```
SENDGRID_API_KEY=SG.xxxxx...
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
```

### Step 9: Install SendGrid package
```bash
source venv/bin/activate
pip install sendgrid-django==5.3.0
```

### Step 10: Restart Django server
```bash
supervisorctl restart auditra
```

### Step 11: Check server status
```bash
supervisorctl status auditra
```

Should show: `RUNNING`

---

## Method 2: Using the Script

If SSH connection works, you can use the provided script:

```bash
chmod +x update_vps_env_sendgrid.sh
./update_vps_env_sendgrid.sh
```

**Note:** The script will add the SendGrid config, but you'll still need to manually replace the placeholder API key with your real one.

---

## What Your .env File Should Look Like

After updating, your `.env` file should have:

```env
# ... your existing settings ...

# SendGrid Email Configuration
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com

# Old SMTP settings (commented out)
# EMAIL_HOST_USER=auditra.auditing.erp@gmail.com
# EMAIL_HOST_PASSWORD=xxxxx
# EMAIL_PORT=587
# EMAIL_USE_TLS=True
```

---

## Quick Test After Update

```bash
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py shell
```

Then in Python:
```python
from django.conf import settings
print(f"SendGrid API Key: {settings.SENDGRID_API_KEY[:10]}...")
print(f"From Email: {settings.DEFAULT_FROM_EMAIL}")
```

If you see your API key and email, the configuration is correct!

---

## Troubleshooting

### If SSH times out:
- Try again after a few minutes
- Check if your VPS is running in DigitalOcean dashboard
- Use DigitalOcean web console as alternative

### If .env file doesn't exist:
```bash
cd /var/www/auditra/backend
touch .env
nano .env
```
Then add all your environment variables including SendGrid config.

### If you get "Permission denied":
Make sure you're logged in as root or use `sudo`:
```bash
sudo nano /var/www/auditra/backend/.env
```

