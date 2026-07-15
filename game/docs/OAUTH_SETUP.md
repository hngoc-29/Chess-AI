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
2. Create **two** client IDs under the same project:
   - **Android**: needs the app's package name (`android/app/build.gradle`
     → `applicationId`) and the SHA-1 fingerprint of your signing key
     (`cd android && ./gradlew signingReport`, use the `debug` variant's
     SHA1 while testing, add the release one before publishing).
   - **iOS**: needs the app's Bundle ID (`ios/Runner.xcodeproj`).
3. Also create a **Web application** client ID - this is the one that goes
   in the *backend's* `GOOGLE_OAUTH_CLIENT_ID` env var (`google_sign_in`
   uses it as the OAuth "audience" even on mobile; the Android/iOS client
   IDs above only authorize the native sign-in flow itself).
4. iOS only: open `ios/Runner/Info.plist` and add a `CFBundleURLTypes`
   entry with your iOS client ID's reversed form (looks like
   `com.googleusercontent.apps.XXXX`) - see the `google_sign_in` package's
   own README for the exact snippet, since this project has no existing
   Info.plist URL scheme to pattern-match against.

Set on the **backend**: `GOOGLE_OAUTH_CLIENT_ID=<web client id>`

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
