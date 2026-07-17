# Setting up Google / Facebook sign-in

Google, guest, and email sign-in are fully implemented and already work
end-to-end against the backend (verified in a local test run this session).
Facebook sign-in is also fully implemented, but **all three providers still
need real credentials from your own developer accounts** before they'll
work on a real device - this is not something that can be done from inside
the codebase. Guest mode works with zero setup.

## 1. Google Sign-In

1. Go to [Google Cloud Console](https://console.cloud.google.com) → APIs &
   Services → Credentials → Create Credentials → OAuth client ID.
2. Create **three** client IDs under the same project - all three need to
   exist, but they're used in different places:

   | Client ID type | What it needs | Where it's used |
   |---|---|---|
   | **Web application** | nothing extra to fill in | `GOOGLE_SERVER_CLIENT_ID` (Flutter build) **and** `GOOGLE_OAUTH_CLIENT_ID` (backend) - same value in both places |
   | **Android** | package name + SHA-1 fingerprint (`cd android && ./gradlew signingReport`, debug variant while testing) | not referenced anywhere in code - Google matches it automatically at sign-in time based on the signed APK |
   | **iOS** | Bundle ID | same as Android: not referenced in Dart code, but `Info.plist` needs a matching URL scheme, see step 4 |

   This trips a lot of people up because it's not obvious: the ID that
   actually goes into your code/env vars is the **Web** one, even though
   the app is mobile-only. The Android/iOS ones just need to *exist* so
   Google recognizes the app itself is allowed to run the native sign-in
   flow at all - see [Google's own docs on this](https://developers.google.com/identity/sign-in/android/backend-auth).
3. iOS only: open `ios/Runner/Info.plist` and add a `CFBundleURLTypes`
   entry with your iOS client ID's reversed form (looks like
   `com.googleusercontent.apps.XXXX`) - see the `google_sign_in` package's
   own README for the exact snippet, since this project has no existing
   Info.plist URL scheme to pattern-match against.

Set on the **Flutter app** (build/run time, not a file to edit):
```
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>.apps.googleusercontent.com
```
Set on the **backend**: `GOOGLE_OAUTH_CLIENT_ID=<same web client id>`

## 2. Facebook Login

1. Go to [developers.facebook.com](https://developers.facebook.com) →
   create an app → add the "Facebook Login" product.
2. Settings → Basic: copy the **App ID** and **App Secret**.
3. Settings → Advanced: copy the **Client Token**.
4. Facebook Login → Settings: add your Android package name + the same
   SHA-1 fingerprint as above; for iOS, add the Bundle ID.

Fill in on the **Flutter app**:
- `android/app/src/main/res/values/strings.xml` - `facebook_app_id`,
  `facebook_client_token`, `fb_login_protocol_scheme` (this last one is
  literally `"fb" + your App ID`, e.g. App ID `123456789` →
  `fb123456789`).
- iOS: `ios/Runner/Info.plist` needs `FacebookAppID`, `FacebookClientToken`,
  `FacebookDisplayName` keys plus a matching `CFBundleURLSchemes` entry -
  see `flutter_facebook_auth`'s README for the exact keys, for the same
  reason as the Google Info.plist note above.

Set on the **backend**: `FACEBOOK_APP_ID=<app id>`,
`FACEBOOK_APP_SECRET=<app secret>`

## 3. After setting env vars on the backend

Restart the backend process (env vars are only read at boot). Until
`GOOGLE_OAUTH_CLIENT_ID` / `FACEBOOK_APP_ID`+`FACEBOOK_APP_SECRET` are set,
`/api/auth/oauth/google` and `/api/auth/oauth/facebook` return a clean 401
rather than crashing - confirmed in this session's testing - so it's safe
to ship Google-only, Facebook-only, or neither while you work through the
above.

## What does NOT need any of this

- Guest sign-in (`Continue as Guest`) - fully local, no credentials, no
  backend call at all.
- Email sign-in (the "Use email instead" fallback) - already using the
  backend's own `/api/auth/register` and `/api/auth/login`.
