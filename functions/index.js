const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ── Haversine distance in meters ─────────────────────────
function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = d => d * Math.PI / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Send FCM to nearby nurses for a call document ────────
async function sendCallNotifications(docId, patientName, urgency, patientLocation) {
  const nursesSnap = await db.collection("users")
    .where("role", "==", "nurse")
    .where("isAvailable", "==", true)
    .get();

  const nearbyNurseIds = [];
  const sendPromises = [];
  const isEmergency = urgency === "emergency";
  const title = isEmergency ? "🚨 EMERGENCY Call" : "🔔 Patient Call";
  const body = `${patientName} needs a nurse`;

  for (const nurseDoc of nursesSnap.docs) {
    const nurse = nurseDoc.data();
    if (!nurse.fcmToken) continue;

    if (patientLocation && nurse.location) {
      const dist = haversineMeters(
        patientLocation.latitude, patientLocation.longitude,
        nurse.location.latitude, nurse.location.longitude
      );
      if (dist > 100) continue;
    }

    nearbyNurseIds.push(nurseDoc.id);
    sendPromises.push(
      admin.messaging().send({
        token: nurse.fcmToken,
        notification: { title, body },
        android: {
          priority: "high",
          notification: {
            channelId: isEmergency ? "healthsign_emergency" : "healthsign_alerts",
            priority: "max",
            visibility: "public",
            defaultVibrateTimings: false,
            vibrateTimingsMillis: ["0", "500", "200", "500"],
          },
        },
        data: { callRequestId: docId, urgency, patientName },
      }).catch(e => console.error(`FCM failed for ${nurseDoc.id}:`, e.message))
    );
  }

  await Promise.all(sendPromises);
  return nearbyNurseIds;
}

// ── Notify nearby nurses when patient rings call bell ─────
// Retries every 30 seconds (up to 5 times) until call is accepted/declined.
exports.notifyNursesOnCallBell = onDocumentCreated(
  { document: "chat_requests/{docId}", timeoutSeconds: 300 },
  async (event) => {
    const data = event.data?.data();
    if (!data || data.status !== "calling") return;

    const patientLocation = data.patientLocation;
    const patientName = data.patientName || "A patient";
    const urgency = data.urgency || "normal";
    const docId = event.params.docId;

    // Initial notification
    const nearbyNurseIds = await sendCallNotifications(
      docId, patientName, urgency, patientLocation
    );
    console.log(`Call bell ${docId}: notified ${nearbyNurseIds.length} nurse(s) (attempt 1)`);
    if (nearbyNurseIds.length > 0) {
      await event.data.ref.update({ nearbyNurseIds });
    }

    // Retry every 30s up to 5 more times while still unanswered
    const maxRetries = 5;
    const retryIntervalMs = 30000;
    for (let attempt = 2; attempt <= maxRetries + 1; attempt++) {
      await new Promise(resolve => setTimeout(resolve, retryIntervalMs));
      const fresh = await event.data.ref.get();
      if (!fresh.exists || fresh.data().status !== "calling") {
        console.log(`Call bell ${docId}: answered/cancelled — stopping retries.`);
        break;
      }
      await sendCallNotifications(docId, patientName, urgency, patientLocation);
      console.log(`Call bell ${docId}: reminder sent (attempt ${attempt})`);
    }
  }
);

// ── Verify caller is superAdmin
async function assertSuperAdmin(auth) {
  console.log("assertSuperAdmin called, auth:", auth ? auth.uid : "null");
  if (!auth) throw new HttpsError("unauthenticated", "Not authenticated.");
  const doc = await db.collection("users").doc(auth.uid).get();
  console.log("doc.exists:", doc.exists, "role:", doc.exists ? doc.data().role : "N/A");
  if (!doc.exists || doc.data().role !== "superAdmin") {
    throw new HttpsError("permission-denied", "Super admin access required.");
  }
}

// Update any user's password
exports.updateUserPassword = onCall({ invoker: "public" }, async (request) => {
  await assertSuperAdmin(request.auth);
  const { uid, newPassword } = request.data;
  if (!uid || !newPassword || newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "uid and newPassword (min 6 chars) required.");
  }
  await admin.auth().updateUser(uid, { password: newPassword });
  return { success: true };
});

// Disable a user account
exports.disableUser = onCall({ invoker: "public" }, async (request) => {
  await assertSuperAdmin(request.auth);
  const { uid } = request.data;
  if (!uid) throw new HttpsError("invalid-argument", "uid required.");
  await admin.auth().updateUser(uid, { disabled: true });
  await db.collection("users").doc(uid).update({ isDisabled: true });
  return { success: true };
});

// Enable a user account
exports.enableUser = onCall({ invoker: "public" }, async (request) => {
  await assertSuperAdmin(request.auth);
  const { uid } = request.data;
  if (!uid) throw new HttpsError("invalid-argument", "uid required.");
  await admin.auth().updateUser(uid, { disabled: false });
  await db.collection("users").doc(uid).update({ isDisabled: false });
  return { success: true };
});
