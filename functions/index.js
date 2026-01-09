const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

function getSmtpConfig() {
  const cfg = functions.config();
  const smtp = cfg.smtp || {};

  if (!smtp.host || !smtp.user || !smtp.pass) {
    throw new Error(
      "Missing SMTP config. Set via firebase functions:config:set smtp.host=... smtp.user=... smtp.pass=..."
    );
  }

  return {
    host: smtp.host,
    port: smtp.port ? Number(smtp.port) : 465,
    secure: smtp.secure ? smtp.secure === "true" : true,
    user: smtp.user,
    pass: smtp.pass,
  };
}

exports.sendQueuedEmail = functions.firestore
  .document("email_queue/{docId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const to = data.to;
    const subject = data.subject || "Reminder";
    const body = data.body || "";

    if (!to) {
      await snap.ref.update({
        status: "error",
        error: "Missing 'to' field",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    let smtp;
    try {
      smtp = getSmtpConfig();
    } catch (e) {
      await snap.ref.update({
        status: "error",
        error: String(e),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const transporter = nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.secure,
      auth: {
        user: smtp.user,
        pass: smtp.pass,
      },
    });

    try {
      await transporter.sendMail({
        from: smtp.user,
        to,
        subject,
        text: body,
      });

      await snap.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await snap.ref.update({
        status: "error",
        error: String(e),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });



