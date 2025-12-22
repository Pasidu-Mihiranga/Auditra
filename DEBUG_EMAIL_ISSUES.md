# Debug Email Sending Issues

## Quick Diagnostic Steps

### 1. Check SendGrid Configuration

SSH into your VPS and run:
```bash
ssh root@152.42.240.220
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py shell
```

Then in Python:
```python
from django.conf import settings
print("Email Backend:", settings.EMAIL_BACKEND)
print("SendGrid API Key:", "SET" if settings.SENDGRID_API_KEY else "NOT SET")
print("From Email:", settings.DEFAULT_FROM_EMAIL)
```

### 2. Test Email Sending Directly

```python
from django.core.mail import send_mail
from django.conf import settings

try:
    send_mail(
        'Test Email',
        'This is a test',
        settings.DEFAULT_FROM_EMAIL,
        ['your-email@example.com'],
        fail_silently=False,
    )
    print("✅ Email sent!")
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
```

### 3. Check Common Issues

#### Issue 1: Sender Email Not Verified
**Error:** "The from address does not match a verified Sender Identity"

**Solution:**
1. Go to https://app.sendgrid.com
2. Navigate to **Settings** → **Sender Authentication**
3. Verify that `auditra.auditing.erp@gmail.com` is verified
4. If not, click "Verify a Single Sender" and complete the process

#### Issue 2: Invalid API Key
**Error:** "Unauthorized" or "Invalid API key"

**Solution:**
1. Check your `.env` file has the correct API key
2. Go to SendGrid dashboard → **Settings** → **API Keys**
3. Verify the API key is active
4. Regenerate if needed

#### Issue 3: Rate Limit Exceeded
**Error:** "Rate limit exceeded"

**Solution:**
- Free tier: 100 emails/day
- Check SendGrid dashboard → **Activity** → **Email Activity**
- Wait until next day or upgrade plan

#### Issue 4: Account Suspended
**Error:** "Account suspended"

**Solution:**
- Check SendGrid dashboard for account status
- Contact SendGrid support if needed

### 4. Check Django Logs

```bash
# Check supervisor logs
tail -f /var/log/supervisor/auditra-stdout.log

# Or check system logs
journalctl -u auditra -f

# Or check Django logs if configured
tail -f /var/www/auditra/backend/logs/*.log
```

### 5. Check SendGrid Dashboard

1. Go to https://app.sendgrid.com
2. Navigate to **Activity** → **Email Activity**
3. Look for your email attempts
4. Check the status (Delivered, Bounced, Blocked, etc.)
5. Click on failed emails to see error details

### 6. Verify Email Service is Being Called

Check if the email service is actually being called by looking at the code flow:
- `CreateClientAccountView` → calls `EmailService.send_account_credentials()`
- Email is sent asynchronously in a thread
- Check logs for "Starting async email send" messages

### 7. Test with the Test Script

I've created `test_email_sendgrid.py` - upload it to your VPS and run:

```bash
cd /var/www/auditra/backend
python test_email_sendgrid.py
```

## Most Common Issue: Sender Not Verified

**90% of email sending failures are due to unverified sender email.**

Make sure:
1. ✅ `auditra.auditing.erp@gmail.com` is verified in SendGrid
2. ✅ `DEFAULT_FROM_EMAIL` in `.env` matches the verified email
3. ✅ You clicked the verification link in the email

## Next Steps

After checking the above:
1. Try sending a test email using the Python shell
2. Check SendGrid dashboard for delivery status
3. Check Django logs for any error messages
4. Share the specific error message you're seeing

