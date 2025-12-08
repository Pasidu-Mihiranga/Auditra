# Quick Setup Guide - Run Your App Now

## Step 1: Start Backend Server

Open a terminal/command prompt and run:

```bash
cd C:\SoftwareProject\Auditra\Auditra\backend
python manage.py runserver
```

**Wait for this message:** `Starting development server at http://127.0.0.1:8000/`
**Keep this terminal open!**

---

## Step 2: Start Flutter App on Chrome

Open a **NEW** terminal/command prompt and run:

```bash
cd C:\SoftwareProject\Auditra\Auditra\auditra
flutter run -d chrome
```

**This will:**
- Build your Flutter app
- Open it in Chrome browser
- Show the login/register screen

---

## Step 3: Test the Register Button

1. Click "Register" on the login screen
2. Fill in the form:
   - Username (required, at least 3 characters)
   - Email (required)
   - Password (required)
   - Confirm Password (must match)
   - First Name (optional)
   - Last Name (optional)
3. Click the "Register" button
4. It should connect to your backend and register the user

---

## Troubleshooting

### If Register button doesn't work:
- Check backend terminal for any error messages
- Make sure backend shows: `Starting development server at http://127.0.0.1:8000/`
- Check Flutter terminal for connection errors

### If you see connection errors:
- Make sure both terminals are running
- Backend must be running BEFORE starting Flutter
- Try refreshing the Chrome page (F5)

### For Android Emulator (later):
- When emulator is working, change `baseUrl` in `auditra/lib/services/api_service.dart` back to:
  ```dart
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  ```

---

## Current Configuration

✅ API URL is set to: `http://localhost:8000/api` (works for Chrome/web)
✅ Backend CORS is configured to allow all origins
✅ Register endpoint is set up correctly

---

**Ready to go! Start with Step 1 above.**














