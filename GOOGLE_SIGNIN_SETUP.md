# Google Sign In Setup Guide for SnatchShot

## 🔐 Security First - Safe Configuration

### ⚠️ IMPORTANT: Never put API keys in code!

**❌ DON'T DO THIS:**
```swift
let clientID = "123456789-abcdef.apps.googleusercontent.com" // ❌ Exposed!
```

**✅ DO THIS INSTEAD:**
```swift
let clientID = Configuration.shared.googleClientID // ✅ Secure!
```

## 📋 Prerequisites

Before implementing Google Sign In, you need to:

### 1. Google Cloud Console Setup

1. **Create/Access Google Cloud Project**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one

2. **Enable Google Sign-In API**:
   - In the Google Cloud Console, go to "APIs & Services" > "Library"
   - Search for "Google Sign-In API"
   - Click "Enable"

3. **Update Existing OAuth 2.0 Credentials**:
   - Go to "APIs & Services" > "Credentials"
   - Find your existing iOS OAuth 2.0 Client ID
   - Click the edit (pencil) icon
   - **Change the Bundle ID to:** `com.rushant.snatchshotapp`
   - If App Check is enabled, you may need to temporarily disable it:
     - Go to "App Check" in the left sidebar
     - Disable App Check for your iOS app
     - Make the bundle ID change
     - Re-enable App Check after testing
   - Click "Save"

### 2. Secure Configuration Setup

✅ **Already Done!** I've created a secure configuration system:

- **Config.xcconfig** - Stores your sensitive data
- **Configuration.swift** - Safely reads configuration
- **.gitignore** - Prevents accidental commits
- **Info.plist** - Uses build-time variables

**Update Config.xcconfig** (this file won't be committed):
```xcconfig
GOOGLE_CLIENT_ID = YOUR_ACTUAL_GOOGLE_CLIENT_ID_HERE
```

## 🔧 Xcode Project Configuration

### 1. Add Configuration File to Build Settings

1. **Select your project** in the Project Navigator
2. **Select your app target**
3. **Go to "Build Settings"**
4. **Search for "xcconfig"**
5. **Double-click the "Config.xcconfig" field**
6. **Add your Config.xcconfig file path**: `SnatchShot/Config.xcconfig`
7. **Make sure it's added to both Debug and Release configurations**

### 2. Add Google Sign In SDK

I've created a `Package.swift` file with the Google Sign In dependency. To add it to your project:

**Option A: Using Xcode (Recommended)**
1. Open your project in Xcode
2. Go to `File` > `Add Package Dependencies...`
3. Enter: `https://github.com/google/GoogleSignIn-iOS.git`
4. Choose version: `Up to Next Major` from `7.0.0`
5. Add to your target: `SnatchShot`

**Option B: Manual Package.swift**
- The `Package.swift` file is already created in your project root
- Xcode should automatically detect and offer to add the dependencies

### 3. Enable Google Sign In in Xcode

1. **Select your project** in the Project Navigator
2. **Select your app target**
3. **Go to "Signing & Capabilities"**
4. **Add the "Sign In with Apple" capability** (required for Google Sign In to work properly)

## 🚀 Implementation Steps

### 1. Update Config.xcconfig

**⚠️ IMPORTANT**: This file contains sensitive information and will **NOT** be committed to version control.

1. **Open Config.xcconfig** in your project
2. **Replace the placeholder** with your actual Google Client ID:
   ```xcconfig
   GOOGLE_CLIENT_ID = 123456789-abcdef.apps.googleusercontent.com
   ```

### 2. Uncomment Google Sign In Code

In these files, uncomment the Google Sign In imports and implementations:

**SignUpView.swift:**
```swift
// Change this line:
// import GoogleSignIn

// To this:
import GoogleSignIn
```

**SnatchShotApp.swift:**
```swift
// Change this line:
// import GoogleSignIn

// To this:
import GoogleSignIn
```

**AppDelegate.swift:**
```swift
// Change this line:
// import GoogleSignIn

// To this:
import GoogleSignIn
```

### 3. Activate Google Sign In Implementation

In `SignUpView.swift`, uncomment the Google Sign In implementation in the `signUpWithGoogle()` function.

In `AppDelegate.swift`, uncomment the Google Sign In configuration in the `application(_:didFinishLaunchingWithOptions:)` method.

## 🧪 Testing Google Sign In

### 1. Physical Device Testing
Google Sign In requires testing on a physical device. Simulator testing is limited.

### 2. Test Account Setup
- Use a Gmail account for testing
- Make sure the account has 2FA enabled for security

### 3. Common Issues & Solutions

**"Sign In Error"**
- Check that your Client ID is correct in Info.plist
- Ensure the bundle ID matches your app's bundle ID
- Verify that "Sign In with Apple" capability is added

**"Invalid Client" Error**
- Double-check your OAuth credentials in Google Cloud Console
- Ensure the bundle ID is exactly correct

**URL Scheme Issues**
- Verify the URL scheme in Info.plist matches your reversed client ID
- Example: If your client ID is `123456789-abcdef.apps.googleusercontent.com`
- URL scheme should be: `com.googleusercontent.apps.123456789-abcdef`

## 🔐 Security Considerations

1. **Never commit Client ID to version control**
   - Add Info.plist to .gitignore
   - Or use build configurations for different environments

2. **Backend Integration**
   - Send the Google ID token to your backend for verification
   - Don't trust user data on the client side

3. **Token Refresh**
   - Google tokens expire, implement refresh logic
   - Store tokens securely using Keychain

## 📱 User Experience

### Expected Flow:
1. User taps "Continue with Google"
2. Safari opens or Google app appears
3. User selects Google account
4. User grants permissions
5. App receives authentication result
6. User proceeds to main app

### Error Handling:
- Network errors
- User cancellation
- Invalid credentials
- Account disabled

## 🎯 Next Steps

1. **Complete Setup**:
   - Get your Google OAuth Client ID
   - Update Info.plist with actual Client ID
   - Add AppDelegate for initialization

2. **Test Thoroughly**:
   - Test on physical iOS device
   - Test error scenarios
   - Verify token handling

3. **Production Deployment**:
   - Set up production OAuth credentials
   - Configure proper error logging
   - Add analytics tracking

## 📚 Additional Resources

- [Google Sign-In for iOS Documentation](https://developers.google.com/identity/sign-in/ios/start)
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0 Setup Guide](https://developers.google.com/identity/protocols/oauth2)

---

**Note**: The Google Sign In code is already implemented in your `SignUpView.swift`. You just need to:
1. Add the SDK dependency
2. Configure your Google Cloud project
3. Update the Client ID in Info.plist
4. Uncomment the Google Sign In code
