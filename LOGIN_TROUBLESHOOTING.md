# Login Troubleshooting Guide

## Why Can't I Log Into an Account That Was Created?

If you're unable to log into an account that was created, follow these steps:

### Step 1: Verify the Account Exists

Run this command in your backend directory:

```bash
cd backend
python manage.py shell
```

Then run:
```python
from django.contrib.auth.models import User
from authentication.models import UserRole

# Replace 'username' with the actual username
username = 'username'
try:
    user = User.objects.get(username=username)
    print(f"✅ User found: {user.username}")
    print(f"   Email: {user.email}")
    print(f"   Is Active: {user.is_active}")
    try:
        print(f"   Role: {user.role.role}")
    except:
        print("   ⚠️  No role assigned!")
except User.DoesNotExist:
    print(f"❌ User '{username}' NOT FOUND!")
```

### Step 2: Check Password Authentication

Test if the password works:

```python
from django.contrib.auth import authenticate

username = 'username'
password = 'password'  # The password you're trying to use

user = authenticate(username=username, password=password)
if user:
    print("✅ Password is CORRECT!")
else:
    print("❌ Password is INCORRECT!")
```

### Step 3: Common Issues and Solutions

#### Issue 1: Wrong Username or Password
**Symptoms:** "Invalid credentials" error

**Solutions:**
- Double-check the username (case-sensitive!)
- Verify the password matches what was used during registration
- Check for extra spaces before/after username or password
- Try resetting the password (see below)

#### Issue 2: User Account Not Active
**Symptoms:** Login fails even with correct credentials

**Check:**
```python
user = User.objects.get(username='username')
print(f"Is Active: {user.is_active}")  # Should be True
```

**Fix:**
```python
user.is_active = True
user.save()
```

#### Issue 3: UserRole Missing
**Symptoms:** Login might work but app crashes or shows errors

**Check:**
```python
try:
    role = user.role
    print(f"Role exists: {role.role}")
except:
    print("No role found!")
```

**Fix:**
```python
from authentication.models import UserRole
UserRole.objects.get_or_create(user=user, defaults={'role': 'unassigned'})
```

#### Issue 4: Case-Sensitive Username
**Symptoms:** "User not found" error

**Note:** Django usernames are case-sensitive!
- `JohnDoe` is different from `johndoe`
- Check the exact case used during registration

**Check all similar usernames:**
```python
User.objects.filter(username__iexact='username')
```

#### Issue 5: Password Not Hashed Properly
**Symptoms:** Password seems correct but authentication fails

**Fix:** Reset the password:
```bash
python manage.py changepassword username
```

Or in Python shell:
```python
user = User.objects.get(username='username')
user.set_password('new_password')
user.save()
print("Password reset successfully!")
```

### Step 4: Reset Password

If you need to reset a password:

**Method 1: Django Management Command**
```bash
cd backend
python manage.py changepassword username
```

**Method 2: Python Shell**
```python
from django.contrib.auth.models import User

user = User.objects.get(username='username')
user.set_password('new_password_here')
user.save()
print("Password reset successfully!")
```

**Method 3: Django Admin**
1. Go to `http://localhost:8000/admin/`
2. Login as admin (username: `admin`, password: `admin@auditra2024`)
3. Go to Users → Select the user → Change password

### Step 5: Verify Backend is Running

Make sure the Django backend server is running:

```bash
cd backend
python manage.py runserver
```

You should see:
```
Starting development server at http://127.0.0.1:8000/
```

### Step 6: Check API Endpoint

Test the login endpoint directly:

```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"username","password":"password"}'
```

Expected response (success):
```json
{
  "user": {...},
  "refresh": "...",
  "access": "...",
  "message": "Login successful"
}
```

Expected response (failure):
```json
{
  "error": "Invalid credentials"
}
```

### Step 7: Check Flutter App Connection

Verify the Flutter app can reach the backend:

1. Check `api_service.dart` - Base URL should be correct:
   - Emulator: `http://10.0.2.2:8000/api`
   - Physical device: `http://YOUR_COMPUTER_IP:8000/api`
   - Web: `http://localhost:8000/api`

2. Check backend is accessible:
   ```bash
   # From your computer, test:
   curl http://localhost:8000/api/auth/login/
   ```

### Step 8: Check Database Migrations

Ensure all migrations are applied:

```bash
cd backend
python manage.py migrate
```

### Step 9: View All Users

List all registered users:

```python
from django.contrib.auth.models import User
from authentication.models import UserRole

users = User.objects.all()
for user in users:
    try:
        role = user.role.role
    except:
        role = "NO ROLE"
    print(f"{user.id}: {user.username} ({user.email}) - Role: {role}")
```

### Step 10: Create Test User

Create a test user to verify registration works:

```python
from django.contrib.auth.models import User
from authentication.models import UserRole

# Create test user
test_user = User.objects.create_user(
    username='testuser',
    email='test@example.com',
    password='testpass123'
)

print(f"✅ Test user created: {test_user.username}")
print(f"   Password: testpass123")
print(f"   Try logging in with these credentials")
```

## Quick Diagnostic Script

Run this complete diagnostic:

```bash
cd backend
python manage.py shell < check_user_account.py
```

Or use the interactive version:
```bash
python manage.py shell
```
Then copy-paste the code from `check_user_account.py`

## Still Having Issues?

1. **Check backend logs** - Look for errors in the terminal where `runserver` is running
2. **Check Flutter console** - Look for error messages in the Flutter debug console
3. **Verify database** - Make sure PostgreSQL is running and connected
4. **Check network** - Ensure Flutter app can reach the backend server

## Common Error Messages

### "Invalid credentials"
- Username or password is incorrect
- Check for typos and case sensitivity

### "User not found"
- Username doesn't exist in database
- Check username spelling and case

### "Connection refused"
- Backend server is not running
- Start with: `python manage.py runserver`

### "Server returned HTML"
- Backend endpoint doesn't exist (404)
- Check URL routing in `backend/authentication/urls.py`

### "Not authenticated"
- Token expired or invalid
- Logout and login again

---

**Need more help?** Check the backend terminal logs and Flutter console for detailed error messages.

