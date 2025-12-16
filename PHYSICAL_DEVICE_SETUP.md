# Setting Up Physical Device for Biometric Testing

This guide will help you connect your Android or iOS phone via USB cable and test biometric authentication.

## For Android Devices

### Step 1: Enable Developer Options

1. Open **Settings** on your Android phone
2. Go to **About Phone** (or **About Device**)
3. Find **Build Number** and tap it **7 times** until you see "You are now a developer!"
4. Go back to Settings and you'll see **Developer Options**

### Step 2: Enable USB Debugging

1. Open **Settings** → **Developer Options**
2. Enable **USB Debugging**
3. Enable **Install via USB** (if available)
4. When you connect your phone, you'll see a prompt asking to "Allow USB debugging" - tap **Allow** and check "Always allow from this computer"

### Step 3: Connect Your Phone

1. Connect your Android phone to your Mac using a USB cable
2. On your phone, when prompted, select **File Transfer** or **MTP** mode (not "Charge only")
3. On your Mac, open Terminal and verify the connection:
   ```bash
   flutter devices
   ```
   You should see your device listed (e.g., "sdk gphone64 arm64" or your phone model)

### Step 4: Update API Base URL (Important!)

Since you're using a physical device, you need to change the API base URL from `10.0.2.2` (emulator) to your Mac's IP address.

1. Find your Mac's IP address:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Look for something like `192.168.1.100` or `192.168.0.105`

2. Update `auditra/lib/services/api_service.dart`:
   ```dart
   // Change this line:
   static const String baseUrl = 'http://10.0.2.2:8000/api';
   
   // To your Mac's IP (example):
   static const String baseUrl = 'http://192.168.1.100:8000/api';
   ```

3. Make sure your Django backend is running:
   ```bash
   cd backend
   source venv/bin/activate
   python manage.py runserver 0.0.0.0:8000
   ```
   (The `0.0.0.0` allows connections from other devices on your network)

### Step 5: Set Up Fingerprint on Your Phone

1. Go to **Settings** → **Security** → **Fingerprint** (or **Biometrics**)
2. Add at least one fingerprint
3. Make sure fingerprint unlock is enabled

### Step 6: Run the App

```bash
cd auditra
flutter run
```

When prompted, select your physical device (not the emulator).

### Step 7: Test Biometric Authentication

1. **During Registration:**
   - Register a new user
   - After successful registration, you should see a dialog asking to enable fingerprint login
   - Tap "Enable" and authenticate with your fingerprint
   - The fingerprint login should now be enabled

2. **During Login:**
   - Logout or close the app
   - Open the app again
   - You should see a "Login with Fingerprint" button
   - Tap it and authenticate with your fingerprint
   - You should be logged in without entering a password

## For iOS Devices

### Step 1: Enable Developer Mode

1. Open **Settings** → **Privacy & Security**
2. Scroll down to **Developer Mode**
3. Enable **Developer Mode**
4. Restart your iPhone when prompted

### Step 2: Trust Your Computer

1. Connect your iPhone to your Mac using a USB cable
2. On your iPhone, when prompted, tap **Trust This Computer**
3. Enter your iPhone passcode

### Step 3: Update API Base URL

Same as Android - update `api_service.dart` with your Mac's IP address.

### Step 4: Set Up Face ID / Touch ID

1. Go to **Settings** → **Face ID & Passcode** (or **Touch ID & Passcode**)
2. Make sure Face ID/Touch ID is set up and enabled

### Step 5: Run the App

```bash
cd auditra
flutter run
```

Select your iPhone from the device list.

### Step 6: Test Biometric Authentication

Same as Android - test during registration and login.

## Troubleshooting

### Device Not Detected

1. **Android:**
   - Make sure USB debugging is enabled
   - Try a different USB cable
   - Check if drivers are installed (usually automatic on Mac)
   - Run `adb devices` to see if device is listed

2. **iOS:**
   - Make sure Developer Mode is enabled
   - Trust the computer on your iPhone
   - Make sure Xcode is installed

### Biometric Not Working

1. **Check Permissions:**
   - Android: Permissions are already added to `AndroidManifest.xml`
   - iOS: Permissions are handled automatically by the `local_auth` package

2. **Check Device Support:**
   - Make sure your device has a fingerprint scanner or Face ID
   - Make sure biometrics are set up in device settings

3. **Check Backend Connection:**
   - Make sure your Mac and phone are on the same Wi-Fi network
   - Make sure the Django backend is running on `0.0.0.0:8000`
   - Test the API URL in your phone's browser: `http://YOUR_MAC_IP:8000/api/`

### API Connection Issues

1. **Firewall:**
   - Make sure your Mac's firewall allows incoming connections on port 8000
   - Go to **System Settings** → **Network** → **Firewall** → **Options** → Add Python to allowed apps

2. **Network:**
   - Make sure both devices are on the same Wi-Fi network
   - Try disabling VPN if you're using one

## Quick Commands

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Check Android devices via ADB
adb devices

# Find your Mac's IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Run Django backend (accessible from network)
cd backend
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

## Notes

- The `local_auth` package automatically handles biometric permissions
- Biometric authentication works on both Android (fingerprint) and iOS (Face ID/Touch ID)
- Make sure to test on a real device - emulators may not support biometrics properly
- The backend must be running and accessible from your phone's network

