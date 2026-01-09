# Email sending (automatic) via Firebase Cloud Functions

The mobile app **queues emails** into Firestore collection `email_queue`.  
To actually send emails automatically (without user interaction), you need a backend.

This folder contains a simple Firebase Cloud Function that:
- Listens to new docs in `email_queue`
- Sends the email using SMTP (Nodemailer)
- Updates the doc status to `sent` or `error`

## Setup (high level)

1. Install Firebase CLI and login:
   - `npm i -g firebase-tools`
   - `firebase login`

2. Initialize functions (if not already):
   - `firebase init functions`
   - Choose **Node.js** and link to your Firebase project

3. Add SMTP credentials to Firebase Functions config:
   - `firebase functions:config:set smtp.host="smtp.gmail.com" smtp.port="465" smtp.secure="true" smtp.user="YOUR_EMAIL" smtp.pass="YOUR_APP_PASSWORD"`
   - For Gmail you must use an **App Password** (not your normal password).

4. Deploy:
   - `firebase deploy --only functions`

## Notes

- Client-side packages like `flutter_email_sender` open the user's email app. They **cannot** send silently in the background.
- Automatic emails require a backend like this function (or any server you control).



