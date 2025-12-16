# USB Device Reconnection Guide

If your Android device stops working after disconnecting and reconnecting the USB cable, follow these steps:

## Quick Fix Steps

### 1. Check USB Connection
```bash
# Check if device is detected
adb devices
```

If you see your device listed, you're good to go. If not, continue with the steps below.

### 2. Restart ADB Server
```bash
# Kill ADB server
adb kill-server

# Start ADB server
adb start-server

# Check devices again
adb devices
```

### 3. Re-enable USB Debugging on Phone
1. On your phone, go to **Settings** → **Developer Options**
2. **Disable** USB Debugging
3. **Enable** USB Debugging again
4. When prompted, tap **Allow** and check "Always allow from this computer"

### 4. Try Different USB Cable/Port
- Try a different USB cable (preferably a data cable, not just charging)
- Try a different USB port on your Mac
- Avoid USB hubs - connect directly to your Mac

### 5. Check USB Connection Mode on Phone
When you connect your phone, make sure you select:
- **File Transfer** or **MTP** mode (not "Charge only")
- Some phones show a notification - tap it and select "File Transfer"

### 6. Verify Flutter Can See Device
```bash
flutter devices
```

You should see your device listed (e.g., "sdk gphone64 arm64" or your phone model).

## Advanced Troubleshooting

### If ADB Still Doesn't See Device

1. **Check USB Drivers** (usually automatic on Mac, but verify):
   ```bash
   # Check if ADB is working
   which adb
   ```

2. **Revoke USB Debugging Authorizations**:
   - On your phone: **Settings** → **Developer Options** → **Revoke USB debugging authorizations**
   - Disconnect and reconnect the cable
   - Tap **Allow** when prompted

3. **Restart Both Devices**:
   - Restart your Mac
   - Restart your Android phone
   - Try connecting again

### If Flutter Can't See Device

1. **Check Flutter Doctor**:
   ```bash
   flutter doctor -v
   ```
   Make sure Android toolchain is properly configured.

2. **Restart Flutter**:
   ```bash
   # Kill any running Flutter processes
   pkill -f flutter
   
   # Try again
   flutter devices
   ```

## Quick Reconnection Script

Create a script to automate the reconnection process:

**For Mac/Linux** (`reconnect_device.sh`):
```bash
#!/bin/bash
echo "Killing ADB server..."
adb kill-server
sleep 2
echo "Starting ADB server..."
adb start-server
sleep 2
echo "Checking devices..."
adb devices
echo "Checking Flutter devices..."
flutter devices
```

Make it executable:
```bash
chmod +x reconnect_device.sh
./reconnect_device.sh
```

## Common Issues and Solutions

### Issue: "device unauthorized"
**Solution**: 
- Revoke USB debugging authorizations on your phone
- Reconnect and tap "Allow" when prompted

### Issue: "device offline"
**Solution**:
```bash
adb kill-server
adb start-server
adb devices
```

### Issue: "no devices found"
**Solution**:
1. Check USB cable (try a different one)
2. Check USB port (try a different port)
3. Enable USB debugging again on phone
4. Select "File Transfer" mode when connecting

### Issue: Device shows but Flutter can't use it
**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

## Prevention Tips

1. **Always use a data cable** (not just charging cable)
2. **Keep USB debugging enabled** on your phone
3. **Don't change USB connection mode** after connecting
4. **Keep your Mac and phone on the same network** (for wireless debugging if needed)

## Wireless Debugging (Alternative)

If USB keeps disconnecting, you can use wireless debugging:

1. **Connect via USB first** (one time setup)
2. **Enable Wireless Debugging** on your phone:
   - Settings → Developer Options → Wireless debugging
   - Note the IP address and port
3. **Connect wirelessly**:
   ```bash
   adb connect <phone-ip>:<port>
   ```
4. **Verify connection**:
   ```bash
   adb devices
   flutter devices
   ```

Now you can disconnect the USB cable and use wireless debugging.

## Still Not Working?

1. Check if your phone's USB port is working (try charging)
2. Try a different computer to isolate the issue
3. Check if your phone's manufacturer has specific USB drivers
4. Update Android SDK Platform Tools:
   ```bash
   # Update via Android Studio or manually download
   ```

## Quick Reference Commands

```bash
# Check devices
adb devices
flutter devices

# Restart ADB
adb kill-server && adb start-server

# Check ADB version
adb version

# List all connected devices
adb devices -l

# Restart Flutter
flutter doctor
flutter devices
```

