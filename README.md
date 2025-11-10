# Table Capture

A lightweight macOS menu bar app that captures screenshots of tables and converts them to CSV or Markdown format.

![macOS](https://img.shields.io/badge/macOS-12.3+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)


## Development

### macOS Security & Permissions Issues

#### Why Does Rebuilding Break Permissions?

When you rebuild the app, macOS often treats it as a "different" application even though it's the same code. This happens because:

1. **Code Signature Changes**: Each build gets a new signature, and macOS ties permissions (like Screen Recording) to that signature
2. **Cached Permissions**: The old permission is still registered but for the "old" app signature
3. **macOS Gets Confused**: It sees your app as brand new and blocks it

#### Solutions

##### Quick Fix (During Development)

```bash
# 1. Kill the app completely
killall TableCapture

# 2. Reset Screen Recording permissions for your app
tccutil reset ScreenCapture com.yourcompany.TableCapture

# 3. Rebuild and run in Xcode
# You'll need to re-grant permission in System Settings → Privacy & Security → Screen Recording
```

##### Better Fix (Consistent Identity)

Set a **stable code signing identity** in Xcode:

1. Go to your project settings → **Signing & Capabilities**
2. Enable **Automatically manage signing**
3. Make sure you have a consistent **Team** selected
4. Ensure your **Bundle Identifier** never changes (e.g., `com.yourname.TableCapture`)

This helps macOS recognize your app across rebuilds.

##### Nuclear Option (When All Else Fails)

```bash
# Reset ALL TCC (privacy) permissions for your app - use carefully!
tccutil reset All com.yourcompany.TableCapture
```

⚠️ **Note**: You'll need to re-grant Screen Recording permission after each rebuild during development. This is annoying but normal for macOS security.

#### For Distribution (Eventually)

When you're ready to distribute the app:
- Sign with a **Developer ID** certificate
- **Notarize** the app with Apple

This makes the signature consistent and permissions stick between launches for your users.

