# Debug Backend 404 Errors

## ✅ Configuration Looks Correct

The backend code shows:
- ✅ URLs are configured: `path('api/attendance/', include('attendance.urls'))`
- ✅ Views exist: `TodayAttendanceView`, `MarkAttendanceView`
- ✅ URLs are defined: `path('today/', ...)`, `path('mark/', ...)`

But endpoints are returning 404 HTML pages.

---

## 🔍 What to Check in Backend Terminal

When you run `python manage.py runserver`, **watch for these:**

### 1. Server Starts Successfully
Should see:
```
Starting development server at http://127.0.0.1:8000/
Quit the server with CTRL-BREAK.
```

### 2. Check for Import Errors
Look for errors like:
- `ModuleNotFoundError`
- `ImportError`
- `NameError`
- `AttributeError`

### 3. Check When You Access Endpoints
When Flutter app tries to access endpoints, backend terminal should show:
```
GET /api/attendance/today/
POST /api/attendance/mark/
```

If you DON'T see these requests, Flutter isn't reaching the backend.

---

## 🚨 Common Issues:

### Issue 1: Backend Has Import Error (MOST LIKELY)

**Check backend terminal for Python errors when server starts.**

**Common errors:**
- `ImportError: cannot import name 'Attendance' from 'attendance.models'`
- `ModuleNotFoundError: No module named 'attendance'`
- `AttributeError: 'Attendance' object has no attribute...`

**Fix:**
```bash
cd backend
python test_endpoints.py
```

This will show import errors.

### Issue 2: Backend Crashed After Starting

**Check if backend terminal is still running.**
- If terminal shows nothing new = server running
- If you see error traceback = server crashed

**Fix:** Restart backend and watch for errors.

### Issue 3: Database Connection Error

**Look for:**
```
django.db.utils.OperationalError: could not connect to server
```

**Fix:**
- Start PostgreSQL
- Check `.env` file has correct database credentials
- Run migrations: `python manage.py migrate`

### Issue 4: Model/Migration Error

**Look for:**
```
django.db.utils.ProgrammingError: relation "attendance_attendance" does not exist
```

**Fix:**
```bash
cd backend
python manage.py makemigrations
python manage.py migrate
```

---

## 📋 Diagnostic Steps:

### Step 1: Run Test Script

```bash
cd backend
python test_endpoints.py
```

**If this fails, it will show the exact error!**

### Step 2: Check Backend Terminal

**When Flutter tries to access endpoints, does backend terminal show:**
- Request logs (GET /api/attendance/today/)
- Error messages
- Python tracebacks

### Step 3: Test in Browser

While backend is running:
```
http://127.0.0.1:8000/api/attendance/today/
```

**What do you see?**
- Django REST Framework page = endpoints work ✅
- 404 page = endpoints don't exist ❌
- Error page = backend has error ❌

---

## 🔧 Quick Fixes:

### Fix 1: Restart Backend and Watch for Errors

```bash
cd backend
python manage.py runserver
```

**Watch the output carefully - copy any errors you see!**

### Fix 2: Run Migrations

```bash
cd backend
python manage.py migrate
```

### Fix 3: Check Database

Make sure PostgreSQL is running and database exists.

---

## ⚠️ IMPORTANT:

**Share with me:**
1. What does backend terminal show when server starts? (Any errors?)
2. When you try to access endpoint in Flutter, does backend terminal show the request?
3. What happens when you visit `http://127.0.0.1:8000/api/attendance/today/` in browser?

This will help identify the exact problem!




































