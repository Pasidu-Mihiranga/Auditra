# Firebase Setup Guide

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select existing project
3. Enter project name: "Auditra" (or your preferred name)
4. Follow the setup wizard:
   - Enable Google Analytics (optional)
   - Accept terms and create project

## Step 2: Enable Required Services

### Authentication
1. In Firebase Console, go to **Authentication** > **Get Started**
2. Enable **Email/Password** sign-in method
3. Enable **Custom** authentication (for custom tokens)

### Cloud Firestore
1. Go to **Firestore Database** > **Create database**
2. Start in **Test mode** (we'll configure security rules later)
3. Choose a location closest to your users
4. Click **Enable**

### Firebase Cloud Messaging (FCM)
1. Go to **Cloud Messaging** > **Get Started**
2. FCM is automatically enabled when you create a Firebase project

### Firebase Storage (Optional - for future file sharing)
1. Go to **Storage** > **Get Started**
2. Start in **Test mode**
3. Choose same location as Firestore

## Step 3: Download Configuration Files

### For Android:
1. In Firebase Console, click the gear icon ⚙️ > **Project settings**
2. Scroll down to "Your apps" section
3. Click **Add app** > Select **Android** icon
4. Enter package name: `com.example.auditra` (check your `android/app/build.gradle` for actual package name)
5. Download `google-services.json`
6. Place it in: `auditra/android/app/google-services.json`

### For iOS:
1. In Firebase Console, click the gear icon ⚙️ > **Project settings**
2. Scroll down to "Your apps" section
3. Click **Add app** > Select **iOS** icon
4. Enter bundle ID: `com.example.auditra` (check your `ios/Runner.xcodeproj` for actual bundle ID)
5. Download `GoogleService-Info.plist`
6. Place it in: `auditra/ios/Runner/GoogleService-Info.plist`

## Step 4: Get Firebase Admin SDK Credentials

For backend integration:
1. In Firebase Console, go to **Project settings** > **Service accounts**
2. Click **Generate new private key**
3. Download the JSON file
4. Save it securely (DO NOT commit to git)
5. Place it in: `backend/firebase-service-account.json` (add to .gitignore)

## Step 5: Update Android Configuration

1. Open `auditra/android/build.gradle`
2. Add to `dependencies`:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

3. Open `auditra/android/app/build.gradle`
4. Add at the bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## Step 6: Update iOS Configuration

1. Open `auditra/ios/Podfile`
2. Ensure platform is iOS 13.0 or higher:
```ruby
platform :ios, '13.0'
```

3. Run:
```bash
cd auditra/ios
pod install
```

## Step 7: Configure Firestore Security Rules

After implementing the chat service, update Firestore rules in Firebase Console:
1. Go to **Firestore Database** > **Rules**
2. Use the security rules provided in the implementation plan
3. Click **Publish**

## Next Steps

After completing this setup:
1. Run `flutter pub get` in the auditra directory
2. The app will automatically initialize Firebase on startup
3. Test Firebase connection by running the app

