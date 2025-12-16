# Fix Login Connection Error

## Problem
```
Connection error: ClientException with SocketException: Connection timed out
address = 10.114.212.139, port = 44278
```

## Root Causes

1. **IP Address Changed** - Your Mac's IP address changed from `10.114.212.139` to `10.174.29.139`
2. **Backend Not Accessible** - Backend is only listening on `localhost` instead of `0.0.0.0`

## Solution

### Step 1: Update IP Address in Flutter App ✅
Already updated `api_service.dart` to use `10.174.29.139`

### Step 2: Restart Backend on 0.0.0.0

**Stop the current backend** (if running):
- Press `Ctrl+C` in the terminal where backend is running

**Start backend on network interface:**
```bash
cd /Users/geemalfernando/Documents/projects/Auditra/backend
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

**Important:** Use `0.0.0.0:8000` NOT `localhost:8000` or `127.0.0.1:8000`

### Step 3: Rebuild Flutter App

```bash
cd /Users/geemalfernando/Documents/projects/Auditra/auditra
flutter clean
flutter pub get
flutter run -d <your-device-id>
```

### Step 4: Verify Connection

**On your phone's browser**, test if backend is accessible:
```
http://10.174.29.139:8000/api/
```

If this loads, the app should work!

## Quick Fix Script

```bash
#!/bin/bash
# Stop any existing backend
pkill -f "manage.py runserver"

# Start backend on network
cd /Users/geemalfernando/Documents/projects/Auditra/backend
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000 &
BACKEND_PID=$!

echo "✅ Backend started on 0.0.0.0:8000"
echo "📱 Update app IP to: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
echo "🔌 Backend PID: $BACKEND_PID"
echo "🛑 To stop: kill $BACKEND_PID"
```

## Check Current IP

To find your current IP address:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Look for the IP in the `10.x.x.x` range (your Wi-Fi IP).

## Troubleshooting

### Still getting timeout?

1. **Check firewall:**
   ```bash
   # Allow Python through firewall
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/python3
   ```

2. **Verify backend is listening:**
   ```bash
   lsof -i :8000
   ```
   Should show `0.0.0.0:8000` not `127.0.0.1:8000`

3. **Test from phone browser:**
   - Open `http://10.174.29.139:8000/api/` on phone
   - If it doesn't load, backend isn't accessible

4. **Check same network:**
   - Phone and Mac must be on same Wi-Fi network

## Prevention

Your IP address can change when:
- Reconnecting to Wi-Fi
- Network changes
- Router restart

**Solution:** Use a static IP or check IP before each session:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```


