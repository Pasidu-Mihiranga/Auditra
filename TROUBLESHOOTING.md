# Troubleshooting Guide - Auditra

Common issues and their solutions.

## 🔴 Backend Issues

### 1. PostgreSQL Connection Error

**Error:**
```
django.db.utils.OperationalError: could not connect to server
```

**Solutions:**

**Check if PostgreSQL is running:**
```bash
# Windows (in Services or)
pg_isready

# Mac
brew services list

# Linux
sudo service postgresql status
```

**Start PostgreSQL:**
```bash
# Mac
brew services start postgresql

# Linux
sudo service postgresql start

# Windows
# Go to Services and start PostgreSQL
```

**Verify database exists:**
```bash
psql -U postgres
\l                    # List databases
CREATE DATABASE auditra_db;  # If not exists
\q
```

### 2. Dependency Installation Error (psycopg)

**Error:**
```
ERROR: Failed to build 'psycopg2-binary' when getting requirements to build wheel
```

**Solution:**
Use `psycopg` instead (already in requirements.txt):
```bash
pip install psycopg==3.1.18
```

### 3. Django Module Not Found

**Error:**
```
ModuleNotFoundError: No module named 'django'
```

**Solution:**
```bash
cd backend
pip install -r requirements.txt
```

**If still not working, try:**
```bash
python -m pip install -r requirements.txt
```

### 4. Migration Errors

**Error:**
```
django.db.migrations.exceptions.InconsistentMigrationHistory
```

**Solution:**
```bash
python manage.py migrate --run-syncdb
```

**Nuclear option (development only):**
```bash
# Delete all migrations (except __init__.py)
python manage.py makemigrations
python manage.py migrate
```

### 5. CORS Error in Browser/App

**Error:**
```
CORS policy: No 'Access-Control-Allow-Origin' header
```

**Solution:**

Verify in `settings.py`:
```python
INSTALLED_APPS = [
    ...
    'corsheaders',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # Must be early
    ...
]

CORS_ALLOW_ALL_ORIGINS = True  # For development
```

### 6. Port Already in Use

**Error:**
```
Error: That port is already in use.
```

**Solution:**

**Windows:**
```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

**Mac/Linux:**
```bash
lsof -ti:8000 | xargs kill -9
```

**Or use different port:**
```bash
python manage.py runserver 8001
```

## 🔵 Flutter Issues

### 1. Connection Refused Error

**Error:**
```
Connection refused: http://localhost:8000/api/auth/login/
```

**Solutions:**

**For Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:8000/api';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:8000/api';
```

**For Physical Device:**
1. Find your computer's IP:
```bash
# Windows
ipconfig

# Mac/Linux
ifconfig
# Look for inet (like 192.168.1.100)
```

2. Update `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://192.168.1.100:8000/api';
```

3. Make sure both devices are on the same WiFi network

4. Update Django `ALLOWED_HOSTS`:
```python
ALLOWED_HOSTS = ['*']  # Or ['192.168.1.100']
```

### 2. Package Dependencies Error

**Error:**
```
Because auditra depends on http ^1.1.0 which doesn't match any versions...
```

**Solution:**
```bash
flutter clean
flutter pub get
```

**If still failing:**
```bash
flutter pub cache repair
flutter pub get
```

### 3. Gradle Build Error (Android)

**Error:**
```
FAILURE: Build failed with an exception.
```

**Solutions:**

**Update Gradle:**
```bash
cd android
./gradlew wrapper --gradle-version=8.0
```

**Clean build:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### 4. CocoaPods Error (iOS)

**Error:**
```
[!] CocoaPods not installed or not in valid state.
```

**Solution:**
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
flutter run
```

### 5. Symlink Error (Windows)

**Error:**
```
Building with plugins requires symlink support.
```

**Solution:**

Enable Developer Mode:
1. Press `Win + I` to open Settings
2. Go to "Privacy & Security" → "For developers"
3. Turn on "Developer Mode"

**Or run as Administrator:**
```powershell
# Run PowerShell as Administrator
flutter run
```

### 6. Hot Reload Not Working

**Solution:**
```bash
# Full restart
r  # In terminal where flutter run is active

# Or restart app
flutter run
```

## 🟡 Common Development Issues

### 1. Token Expired Error

**Error:**
```
{"detail": "Given token not valid for any token type"}
```

**Solutions:**

**Clear app data:**
- Long press app icon → App Info → Clear Data

**Or logout and login again**

**Or increase token lifetime in Django:**
```python
# settings.py
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),  # Instead of 1
    ...
}
```

### 2. Cannot Login After Registration

**Check:**
1. Is Django server running?
2. Check Django terminal for errors
3. Test API directly with cURL:
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
```

### 3. Blank White Screen

**Solutions:**
1. Check Flutter terminal for errors
2. Hot restart: `R` in terminal
3. Rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

### 4. Database Locked Error

**Error:**
```
django.db.utils.OperationalError: database is locked
```

**Solution (if using SQLite accidentally):**
```bash
# Close all Django admin/shell sessions
# Or delete db.sqlite3 if you have PostgreSQL configured
```

### 5. Import Errors in Flutter

**Error:**
```
Target of URI doesn't exist: 'package:auditra/screens/login_screen.dart'
```

**Solution:**
```bash
flutter pub get
# Restart IDE/Editor
```

## 🔧 Development Tips

### Verify Backend Setup

```bash
cd backend
python check_setup.py
```

### Test Backend API

```bash
# Test registration
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "email":"test@test.com",
    "password":"test12345",
    "password2":"test12345"
  }'

# Test login
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "password":"test12345"
  }'
```

### Check Flutter Console

Look for detailed error messages:
```bash
flutter run -v  # Verbose mode
```

### Enable Django Debug Toolbar (Optional)

```bash
pip install django-debug-toolbar
# Add to INSTALLED_APPS and MIDDLEWARE in settings.py
```

## 📱 Device-Specific Issues

### Android

**Issue: App not installing**
```bash
flutter clean
flutter pub get
flutter run --release
```

**Issue: Network permissions**
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS

**Issue: App not running on device**
1. Check code signing in Xcode
2. Trust developer certificate on device
3. Rebuild:
```bash
cd ios
pod install
cd ..
flutter run
```

## 🆘 Still Having Issues?

### Checklist

- [ ] PostgreSQL is installed and running
- [ ] Database `auditra_db` exists
- [ ] Django server is running (`python manage.py runserver`)
- [ ] Django shows no errors in terminal
- [ ] Flutter dependencies are installed (`flutter pub get`)
- [ ] Correct API URL in `api_service.dart`
- [ ] Both devices on same network (for physical device)
- [ ] `.env` file exists in backend directory
- [ ] All migrations applied (`python manage.py migrate`)

### Get More Help

1. **Check Django logs** in the terminal
2. **Check Flutter console** for error details
3. **Test API with Postman** or cURL
4. **Clear all caches:**
   ```bash
   # Flutter
   flutter clean
   flutter pub get
   
   # Django
   python manage.py collectstatic --clear
   ```

### Nuclear Reset (Last Resort)

```bash
# Backend
cd backend
rm -rf __pycache__
rm db.sqlite3  # If exists
python manage.py migrate
python manage.py createsuperuser

# Frontend
cd auditra
flutter clean
flutter pub get
flutter run
```

## 📚 Useful Commands

### Django

```bash
python manage.py runserver              # Start server
python manage.py makemigrations        # Create migrations
python manage.py migrate               # Apply migrations
python manage.py createsuperuser       # Create admin
python manage.py shell                 # Django shell
python manage.py test                  # Run tests
```

### Flutter

```bash
flutter doctor                         # Check setup
flutter devices                        # List devices
flutter run                           # Run app
flutter clean                         # Clean build
flutter pub get                       # Get dependencies
flutter build apk                     # Build Android APK
flutter build ios                     # Build iOS
```

### PostgreSQL

```bash
psql -U postgres                      # Connect
\l                                    # List databases
\c auditra_db                         # Connect to database
\dt                                   # List tables
\q                                    # Quit
```

---

**Still stuck?** Create an issue with:
1. Error message (full text)
2. Steps to reproduce
3. Your environment (OS, Flutter version, Python version)

