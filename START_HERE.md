# 🚀 START HERE - Auditra Setup Guide

Welcome to Auditra! This guide will get you up and running in minutes.

## 📋 What You Have

✅ **Flutter Mobile App** with Login, Registration, and Home screens  
✅ **Django REST API** with JWT authentication  
✅ **PostgreSQL Database** configuration  
✅ **Complete Documentation**

## 🎯 Quick Start (Choose Your Path)

### 🏃 Path 1: Fast Setup (5 minutes)
Perfect if you just want to see it working quickly.

👉 **[Follow QUICKSTART.md](QUICKSTART.md)**

### 📚 Path 2: Detailed Setup (15 minutes)
Understand everything as you set it up.

👉 **[Follow README.md](README.md)**

## 📖 Documentation Overview

| File | Purpose | When to Use |
|------|---------|-------------|
| **START_HERE.md** | You are here! | First time setup |
| **QUICKSTART.md** | 5-minute setup | Quick setup |
| **README.md** | Complete guide | Full documentation |
| **PROJECT_SUMMARY.md** | Architecture overview | Understanding the project |
| **TROUBLESHOOTING.md** | Problem solutions | When you face issues |
| **backend/README.md** | Backend docs | Django-specific help |
| **auditra/README.md** | Frontend docs | Flutter-specific help |

## 🎬 Your First Steps

### 1️⃣ Prerequisites Check

Make sure you have:
- [ ] **Flutter SDK** installed ([Get Flutter](https://flutter.dev/docs/get-started/install))
- [ ] **Python 3.9+** installed ([Get Python](https://www.python.org/downloads/))
- [ ] **PostgreSQL** installed ([Get PostgreSQL](https://www.postgresql.org/download/))
- [ ] **Code Editor** (VS Code, Android Studio, etc.)

**Quick Check:**
```bash
flutter doctor        # Should show Flutter is ready
python --version      # Should show Python 3.9+
psql --version        # Should show PostgreSQL version
```

### 2️⃣ Create PostgreSQL Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database (in PostgreSQL shell)
CREATE DATABASE auditra_db;
\q
```

### 3️⃣ Setup Backend

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Create .env file with your PostgreSQL password
# Copy and paste this, replace YOUR_PASSWORD:
echo "DB_NAME=auditra_db
DB_USER=postgres
DB_PASSWORD=YOUR_PASSWORD
DB_HOST=localhost
DB_PORT=5432" > .env

# Run migrations
python manage.py migrate

# (Optional) Verify setup
python check_setup.py

# Start server
python manage.py runserver
```

**✓ Backend should now be running at http://localhost:8000**

### 4️⃣ Setup Frontend

Open a **new terminal** (keep backend running):

```bash
cd auditra

# Install dependencies
flutter pub get

# Configure API URL (important!)
# Edit lib/services/api_service.dart:
# - Line 10: Change baseUrl based on your device:
#   • Android Emulator: http://10.0.2.2:8000/api
#   • iOS Simulator: http://localhost:8000/api
#   • Physical Device: http://YOUR_COMPUTER_IP:8000/api

# Run app
flutter run
```

**✓ App should now be running on your device/emulator**

## 🎉 Test Your App

1. **Launch the app** - You'll see the splash screen, then login
2. **Click "Register"** - Create a new account
3. **Fill the form** - Use any username, email, and password
4. **Submit** - You'll be automatically logged in
5. **See your profile** - View the home screen with your info
6. **Logout** - Test logout and login again

## 🔍 Verify Everything Works

### Test Backend API

```bash
# Test registration endpoint
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@test.com","password":"pass1234","password2":"pass1234"}'

# You should see a success response with tokens
```

### Test Flutter App

1. Register a user
2. Logout
3. Login again with same credentials
4. Profile should display correctly

## ⚠️ Common First-Time Issues

### "Connection refused" in app

**Problem:** App can't reach Django server

**Fix:** Update `baseUrl` in `lib/services/api_service.dart`:
- **Android Emulator:** `http://10.0.2.2:8000/api`
- **iOS Simulator:** `http://localhost:8000/api`
- **Physical Device:** `http://YOUR_IP:8000/api`

Find your IP:
```bash
# Windows
ipconfig

# Mac/Linux
ifconfig | grep inet
```

### "Database connection error"

**Problem:** Can't connect to PostgreSQL

**Fix:**
1. Make sure PostgreSQL is running
2. Check `.env` file has correct password
3. Verify database exists: `psql -U postgres -l`

### "Module not found" errors

**Backend:**
```bash
cd backend
pip install -r requirements.txt
```

**Frontend:**
```bash
cd auditra
flutter pub get
```

## 📱 Testing on Different Devices

### Android Emulator
```bash
flutter emulators                    # List emulators
flutter emulators --launch <id>     # Start one
flutter run                         # Run app
```

### iOS Simulator (Mac only)
```bash
open -a Simulator
flutter run
```

### Physical Device

1. Enable USB Debugging (Android) or Trust Computer (iOS)
2. Connect device via USB
3. Find your computer's IP: `ipconfig` or `ifconfig`
4. Update `baseUrl` in `api_service.dart` to your IP
5. Update `ALLOWED_HOSTS` in Django `settings.py` to include your IP
6. Run: `flutter run`

## 🎓 Next Steps After Setup

### Learn the Architecture
👉 Read **PROJECT_SUMMARY.md** to understand how everything connects

### Customize the App
- Change colors in `lib/main.dart`
- Modify screens in `lib/screens/`
- Add new API endpoints in `backend/authentication/`

### Add Features
- Profile editing
- Password reset
- Profile pictures
- More pages and functionality

## 🆘 Need Help?

### Something not working?
👉 Check **TROUBLESHOOTING.md** for solutions

### Want to understand more?
👉 Read **README.md** for detailed documentation

### Backend issues?
👉 Check **backend/README.md**

### Frontend issues?
👉 Check **auditra/README.md**

## 💡 Pro Tips

1. **Keep both terminals open** - One for Django, one for Flutter
2. **Check Django terminal** - See all API requests in real-time
3. **Use hot reload** - Save files in Flutter for instant updates
4. **Test API first** - Use cURL or Postman before testing in app
5. **Enable Developer Mode** - On Windows for symlink support

## ✅ Setup Checklist

Before you start coding, verify:

- [ ] PostgreSQL is running
- [ ] Database `auditra_db` exists
- [ ] Backend dependencies installed
- [ ] `.env` file created with correct password
- [ ] Django migrations applied
- [ ] Django server running (http://localhost:8000)
- [ ] Flutter dependencies installed
- [ ] API URL configured correctly in `api_service.dart`
- [ ] App runs without errors
- [ ] Can register and login successfully

## 🎊 You're All Set!

If you've completed the setup, you now have:
- ✅ A working Flutter app
- ✅ A working Django API
- ✅ PostgreSQL database
- ✅ Full authentication system
- ✅ JWT token management
- ✅ Beautiful UI

**Time to build something amazing! 🚀**

---

**Questions or issues?** Open an issue or check the troubleshooting guide.

**Happy Coding! 💻**

