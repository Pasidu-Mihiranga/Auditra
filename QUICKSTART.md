# Quick Start Guide - Auditra

Get up and running in 5 minutes!

## 🚀 Quick Setup

### 1️⃣ Backend Setup (2 minutes)

```bash
# Navigate to backend
cd backend

# Install dependencies
pip install -r requirements.txt

# Create and configure database
# Open PostgreSQL and run:
# CREATE DATABASE auditra_db;

# Create .env file with your PostgreSQL password
echo "DB_NAME=auditra_db
DB_USER=postgres
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432" > .env

# Run migrations
python manage.py migrate

# Start server
python manage.py runserver
```

✅ Backend running at: http://localhost:8000

### 2️⃣ Frontend Setup (2 minutes)

```bash
# Navigate to Flutter app (open new terminal)
cd auditra

# Install dependencies
flutter pub get

# Update API URL in lib/services/api_service.dart
# For Android Emulator: http://10.0.2.2:8000/api
# For iOS Simulator: http://localhost:8000/api
# For Physical Device: http://YOUR_IP:8000/api

# Run app
flutter run
```

✅ App running on your device/emulator!

## 📱 Test the App

1. **Register a new account**
   - Open the app
   - Click "Register"
   - Fill in the form
   - Submit

2. **Login**
   - Use your credentials
   - Click "Login"
   - You'll be redirected to the home screen

3. **View Profile**
   - See your user information on the home screen
   - Logout when done

## 🐛 Common Issues

### Can't connect to backend?

**Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:8000/api';
```

**iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:8000/api';
```

**Physical Device:**
1. Find your computer's IP:
   - Windows: `ipconfig`
   - Mac/Linux: `ifconfig`
2. Update URL:
```dart
static const String baseUrl = 'http://192.168.1.XXX:8000/api';
```

### PostgreSQL not found?

**Install PostgreSQL:**
- Windows: https://www.postgresql.org/download/windows/
- Mac: `brew install postgresql`
- Linux: `sudo apt-get install postgresql`

### Database connection error?

Make sure PostgreSQL is running:
```bash
# Mac
brew services start postgresql

# Linux
sudo service postgresql start

# Windows
# Start PostgreSQL from Services
```

## 📊 Testing API with cURL

```bash
# Register
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","email":"demo@test.com","password":"demo1234","password2":"demo1234"}'

# Login
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"demo1234"}'
```

## 🎉 Next Steps

1. Customize the UI colors in `main.dart`
2. Add more features to the home screen
3. Implement additional API endpoints
4. Add profile editing functionality
5. Implement password reset

## 📚 Full Documentation

See [README.md](README.md) for complete documentation.

## 💡 Tips

- Use Django Admin: Create superuser with `python manage.py createsuperuser`
- Access admin at: http://localhost:8000/admin
- View API docs: Can add DRF browsable API
- Hot reload: Save files in Flutter for instant updates

---

**Need help?** Check the main README or open an issue!

