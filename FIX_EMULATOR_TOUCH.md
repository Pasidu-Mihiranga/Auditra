# Fix Emulator Touch Input Issue

## Problem: Can't touch/interact with Android emulator

## Solutions:

### Solution 1: Cold Boot Emulator (Best Fix)
1. Close Android Studio completely
2. Open Android Studio → Tools → Device Manager
3. Click dropdown arrow (▼) next to your emulator
4. Select **"Cold Boot Now"**
5. Wait 2-3 minutes for complete boot
6. Try touching the screen

### Solution 2: Change Graphics Settings
1. Android Studio → Tools → Device Manager
2. Click **Edit** (pencil icon) next to your emulator
3. Click **Show Advanced Settings**
4. Set **Graphics** to: **Hardware - GLES 2.0**
5. Click **Finish**
6. Restart emulator

### Solution 3: Increase Emulator Performance
1. Android Studio → Tools → Device Manager
2. Click **Edit** (pencil icon)
3. Click **Show Advanced Settings**
4. Increase **RAM** to: **4096 MB**
5. Set **VM heap** to: **512 MB**
6. Enable **Multi-core CPU**: **2-4 cores**
7. Click **Finish** and restart

### Solution 4: Enable Touch in Settings
If emulator is running but touch doesn't work:
1. In emulator, click **⋮** (three dots) to open Extended Controls
2. Go to **Settings** tab
3. Check **Send keyboard input to device**
4. Try using mouse click as touch

### Solution 5: Use Physical Device Instead
Connect your Android phone via USB:
1. Enable **Developer Options** on phone
2. Enable **USB Debugging**
3. Connect via USB cable
4. Run: `flutter run`
5. Select your physical device

### Solution 6: Use Chrome (Easiest Alternative)
```bash
flutter run -d chrome
```
No emulator needed! Works immediately.

---

## After Fixing:
1. Update API URL in `auditra/lib/services/api_service.dart`:
   - For emulator: `http://10.0.2.2:8000/api` ✅ (already done)
   - For Chrome: `http://localhost:8000/api`
   - For physical device: `http://YOUR_COMPUTER_IP:8000/api`

2. Make sure backend is running:
   ```bash
   cd backend
   python manage.py runserver
   ```

3. Run Flutter app:
   ```bash
   cd auditra
   flutter run
   ```

---

## Why This Happens:
- Emulator graphics acceleration issues
- Insufficient RAM allocation
- First boot takes longer
- Virtualization not properly configured
- Touch input driver not initialized

---

## Quick Test:
After restart, try:
- Clicking on the screen
- Tapping buttons
- Swiping
- Using keyboard (should work as input)



























