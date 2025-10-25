# SnatchShot 📸✨

**AI-Powered Fashion Styling App** - Get personalized fashion recommendations and outfit suggestions using advanced AI and computer vision.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 🌟 Features

- **AI-Powered Pose Analysis**: Advanced computer vision to analyze your poses and body type
- **Personalized Recommendations**: Get fashion suggestions tailored to your style and preferences
- **Real-time Processing**: WebSocket-powered real-time image processing and feedback
- **Fashion Gallery**: Browse and manage your styled photos
- **Social Integration**: Google Sign-In for seamless user experience
- **Premium Features**: Superwall-powered subscriptions for enhanced functionality

## 📱 Screenshots

*Screenshots coming soon*

## 🚀 Quick Start

### Prerequisites

- **macOS 13.0+**
- **Xcode 15.0+**
- **iOS 15.0+** device or simulator
- **Swift 5.9+**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Rushant-123/slay-ai.git
   cd slay-ai
   ```

2. **Install dependencies**
   ```bash
   # Swift Package Manager handles all dependencies automatically
   open SnatchShot.xcodeproj
   ```

3. **Configure Environment**
   ```bash
   # Copy the example environment file
   cp .env.example .env

   # Edit .env with your actual configuration values
   nano .env
   ```

4. **Configure Build Settings**
   ```bash
   # Copy and configure your secrets
   cp SnatchShot/Config.xcconfig.example SnatchShot/Config.xcconfig

   # Edit Config.xcconfig with your actual API keys and URLs
   nano SnatchShot/Config.xcconfig
   ```

5. **Build and Run**
   ```bash
   # In Xcode: Product → Run (⌘R)
   # Or use command line:
   xcodebuild -project SnatchShot.xcodeproj -scheme SnatchShot -sdk iphonesimulator
   ```

## ⚙️ Configuration

### Required Environment Variables

Create a `.env` file in the project root:

```bash
# Google Sign In Configuration
GOOGLE_CLIENT_ID=your_google_client_id_here.apps.googleusercontent.com

# Database API Configuration
DATABASE_API_BASE_URL=http://your_api_domain.com/api
DATABASE_API_TIMEOUT=30

# WebSocket Configuration
WEBSOCKET_BASE_URL=ws://your_websocket_domain.com:4001

# Analytics Configuration
MIXPANEL_TOKEN=your_mixpanel_token_here

# AppsFlyer Configuration
APPSFLYER_DEV_KEY=your_appsflyer_dev_key_here
APPLE_APP_ID=your_apple_app_id_here
```

### Build Configuration (Config.xcconfig)

The `SnatchShot/Config.xcconfig` file contains build-time configuration:

```xcconfig
// Google Sign In Configuration
GOOGLE_CLIENT_ID = your_google_client_id_here.apps.googleusercontent.com

// Database API Configuration
DATABASE_API_BASE_URL = http://your_api_domain.com/api
DATABASE_API_TIMEOUT = 30

// WebSocket Configuration
WEBSOCKET_BASE_URL = ws://your_websocket_domain.com:4001

// Apple Sign In Configuration
APPLE_TEAM_ID = your_team_id
APPLE_SERVICES_ID = com.yourdomain.yourapp.signin
APPLE_KEY_ID = your_key_id
APPLE_PRIVATE_KEY = -----BEGIN PRIVATE KEY-----...

// Analytics Configuration
MIXPANEL_TOKEN = your_mixpanel_token

// AppsFlyer Configuration
APPSFLYER_DEV_KEY = your_appsflyer_key
APPLE_APP_ID = your_apple_app_id
```

## 🏗️ Architecture

### Core Components

- **Camera Service**: Handles camera capture and processing
- **WebSocket Service**: Real-time communication with AI backend
- **Database Service**: API communication and data management
- **Configuration**: Centralized configuration management
- **Analytics**: User behavior tracking and insights

### Key Technologies

- **SwiftUI**: Modern, declarative UI framework
- **Combine**: Reactive programming for state management
- **AVFoundation**: Camera and media processing
- **Metal**: GPU-accelerated image processing
- **Superwall**: Subscription and paywall management
- **WebSocket**: Real-time bidirectional communication

## 🔧 Development

### Project Structure

```
SnatchShot/
├── Camera/                 # Camera and image processing
│   ├── CameraView.swift
│   ├── CameraService.swift
│   └── PoseSuggestionsView.swift
├── DatabaseService.swift    # API communication
├── WebSocketService.swift   # Real-time messaging
├── Configuration.swift      # App configuration
├── GalleryView.swift        # Photo gallery
├── SubscriptionManager.swift # Premium features
└── Config.xcconfig         # Build configuration
```

### Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for code quality
- Document complex logic with comments
- Prefer SwiftUI over UIKit where possible

### Testing

```bash
# Run unit tests
xcodebuild test -project SnatchShot.xcodeproj -scheme SnatchShot

# Run UI tests
xcodebuild test -project SnatchShot.xcodeproj -scheme SnatchShotUITests
```

## 🔒 Security

- **Never commit secrets**: API keys, tokens, and private keys are excluded from version control
- **Environment variables**: Use `.env` files for local development
- **Build configuration**: Sensitive data is managed through `Config.xcconfig`
- **HTTPS only**: All network requests use secure connections

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes** and test thoroughly
4. **Commit your changes**: `git commit -m "Add your feature"`
5. **Push to your fork**: `git push origin feature/your-feature-name`
6. **Create a Pull Request**

### Guidelines

- **Code Review**: All PRs require review before merging
- **Tests**: Add tests for new features
- **Documentation**: Update README and code comments
- **Security**: Never expose sensitive information

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋 Support

- **Issues**: [GitHub Issues](https://github.com/Rushant-123/slay-ai/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Rushant-123/slay-ai/discussions)
- **Documentation**: Check the `*_README.md` files in the project

## 🏆 Acknowledgments

- **AI/ML Team**: For the amazing pose analysis and styling algorithms
- **Design Team**: For the beautiful UI/UX design
- **Open Source Community**: For the amazing libraries and tools

---

**Made with ❤️ for fashion lovers worldwide**
