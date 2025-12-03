# Debug Register Button Issue

## I've added debug logging to help identify the problem

When you click Register, check your Flutter terminal for these messages:

### Expected Flow:
1. `🟢 Register button clicked!` - Button is working
2. `✅ Form validation passed` - Form is valid
3. `🟡 Starting registration...` - API call starting
4. `🔵 Registering user: [username]` - API service called
5. `🔵 API URL: http://10.0.2.2:8000/api/auth/register/` - URL being used
6. `🔵 Response status: 201` - Success (or error code)
7. `✅ Registration successful!` - Done!

---

## Common Issues & Fixes:

### Issue 1: No messages appear at all
**Problem:** Button click not registering
**Solution:**
- Make sure you're looking at the Flutter terminal (not backend)
- Try hot reload: Press `r` in Flutter terminal
- Check if button shows loading spinner (means it's working)

### Issue 2: "❌ Form validation failed"
**Problem:** Required fields not filled correctly
**Solution:**
- Username: At least 3 characters
- Email: Must contain @
- Password: Must match confirm password
- All required fields must be filled

### Issue 3: "Connection error" or "Failed host lookup"
**Problem:** Backend not running or wrong URL
**Solution:**
1. **Check backend is running:**
   ```bash
   cd backend
   python manage.py runserver
   ```
   Should see: `Starting development server at http://127.0.0.1:8000/`

2. **Verify API URL:**
   - For Android emulator: `http://10.0.2.2:8000/api` ✅ (current)
   - For Chrome: `http://localhost:8000/api`
   - Check file: `auditra/lib/services/api_service.dart` line 10

3. **Test backend manually:**
   Open browser: `http://127.0.0.1:8000/api/auth/register/`
   Should see Django REST Framework page (not 404 error)

### Issue 4: "Response status: 400" (Bad Request)
**Problem:** Invalid data sent to backend
**Solution:**
- Check Flutter terminal for error details
- Common causes:
  - Username already exists
  - Email already exists
  - Password too weak (minimum 8 characters)
  - Missing required fields

### Issue 5: "Response status: 500" (Server Error)
**Problem:** Backend error
**Solution:**
- Check backend terminal for error messages
- Database might not be set up
- Run migrations:
  ```bash
  cd backend
  python manage.py migrate
  ```

### Issue 6: Button shows loading but nothing happens
**Problem:** API call hanging
**Solution:**
- Backend might not be accessible from emulator
- Try restarting backend
- Check firewall isn't blocking
- Try using Chrome instead: `flutter run -d chrome`

---

## Quick Test Checklist:

- [ ] Backend is running (`python manage.py runserver`)
- [ ] Backend shows: `Starting development server at http://127.0.0.1:8000/`
- [ ] Flutter app is running
- [ ] Looking at Flutter terminal (not backend terminal)
- [ ] All form fields are filled correctly
- [ ] Passwords match
- [ ] API URL is correct for your platform (emulator = 10.0.2.2)

---

## Still Not Working?

1. **Share the Flutter terminal output** - All the 🟢🔵🟡 messages
2. **Share the backend terminal output** - Any errors there?
3. **What device are you using?** (emulator, Chrome, physical device)
4. **Do you see any error messages in the app?** (red snackbar)

---

## Manual Backend Test:

Test if backend is working:
```bash
curl -X POST http://127.0.0.1:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testuser\",\"email\":\"test@example.com\",\"password\":\"testpass123\",\"password2\":\"testpass123\"}"
```

If this works, backend is fine. Problem is Flutter connection.


