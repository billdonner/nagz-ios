# Nagz — TestFlight Release Notes — Build 6 (1.0.0)

## What's New

**Trusted Connections — Nag Each Other's Kids**
- Connected adults can now mark a connection as "trusted" in the People tab
- When trusted, you can create nags for the other person's children — no extra setup needed
- Toggle trust on/off with a single tap; untrusting automatically cancels any open trusted-child nags
- Trusted children appear in the Create Nag recipient picker under "Trusted Connections' Kids"

**Share Invites Easily**
- After sending a connection invite, tap the Share button to send via iMessage, WhatsApp, email, etc.
- Pre-written message includes a nagz.online link

**Better Login Experience**
- Token refresh now works correctly — no more "You don't have permission" errors after session expiry
- App stays logged in reliably across relaunches

**People Tab Improvements**
- New "Invites You Sent" section shows pending outbound invitations with cancel button
- Friendlier error message when inviting someone you're already connected with

**Tab Persistence**
- App remembers which tab you were on and returns to it when relaunched

## Under the Hood
- 560 total tests passing across all repos (215 iOS, 219 server, 126 web)
- Server scaled to 512 MB RAM with auto-restart after 1,000 requests
- Full cross-repo audit completed — all docs in sync

## What to Test

1. **Trusted Connections**: Go to People tab → find an active connection → toggle the "Trusted" switch → go to Create Nag → check if the other person's kids appear as recipients
2. **Share Invite**: People tab → invite a new email → after success, tap Share and send via any channel
3. **Session Persistence**: Force-quit and reopen — you should stay logged in and return to the same tab
4. **Outbound Invites**: People tab → check "Invites You Sent" section
5. **Everything else**: All existing features should work as before

## Known Issues
- None new in this build

## Previous Builds
- Build 5: Auth error fix (401 vs 403), production server connection
- Build 4: Production URL fix for server connection
- Build 3: Onboarding carousel, new icon/branding
