# Privacy Policy

Last updated: 2026-06-27

Event Gift Keeper helps users record and organize event gifts. This policy explains what information the app uses and why.

## Information We Collect

The app may collect:

- Account information used for sign-in, such as your Firebase/Google user ID and email address.
- Gift entries you create, including giver names, gift descriptions, monetary amounts, currencies, and dates.
- Short audio recordings when you choose to use AI voice capture.
- App diagnostics such as crash reports and basic technical logs.

## How Information Is Used

Information is used to:

- Save and sync your gift entries.
- Transcribe and parse gift recordings through Cloud Functions and AI services.
- Generate exports such as PDF or CSV.
- Improve reliability, debug crashes, and protect the service from abuse.

## Audio and AI Processing

When you use voice capture, audio is sent to Firebase Cloud Functions for transcription and parsing. The app does not intentionally store raw audio after processing. Transcripts may be used temporarily to show recognition results and create gift entries.

## Data Storage

Gift entries are stored in Firebase Firestore under your authenticated user account. Firestore security rules are configured so users can only access their own gift entries.

## Sharing

We do not sell personal information. Data may be processed by service providers required to run the app, including Firebase/Google Cloud and AI processing services.

## Data Deletion

You can delete gift entries inside the app. For account or data deletion requests, contact the support email listed in the store listing.

## Children

The app is not intended for children under 13.

## Contact

TODO: Add final support email.
