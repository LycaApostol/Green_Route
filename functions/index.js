const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// =====================
// SET ADMIN CLAIM
// =====================
/**
 * Manually set admin role for a user
 * Can ONLY be called via Firebase Console, CLI, or secure backend
 */
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Optional: restrict who can call this function
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can assign admin privileges",
    );
  }

  const {uid} = data;
  if (!uid) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "UID is required",
    );
  }

  try {
    await admin.auth().setCustomUserClaims(uid, {admin: true});
    return {message: `Successfully set admin claim for UID: ${uid}`};
  } catch (error) {
    throw new functions.https.HttpsError("unknown", error.message, error);
  }
});

// =====================
// Check if user has admin privileges
// =====================
exports.checkAdminStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    return {isAdmin: false};
  }

  return {
    isAdmin: context.auth.token.admin === true,
    uid: context.auth.uid,
    email: context.auth.token.email,
  };
});

// =====================
// Get all user feedback (Admin only)
// =====================
exports.getAllFeedback = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  try {
    const snapshot = await admin.firestore()
        .collection("feedback")
        .orderBy("createdAt", "desc")
        .get();

    const feedback = [];
    snapshot.forEach((doc) => {
      feedback.push({id: doc.id, ...doc.data()});
    });

    return {feedback};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =====================
// Update feedback status (Admin only)
// =====================
exports.updateFeedbackStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  const {feedbackId, status, adminNotes} = data;

  try {
    await admin.firestore().collection("feedback").doc(feedbackId).update({
      status: status,
      adminNotes: adminNotes || "",
      reviewedBy: context.auth.uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =====================
// Create system-wide alert (Admin only)
// =====================
exports.createAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  const {title, message, type, priority} = data;

  try {
    const alertRef = await admin.firestore().collection("alerts").add({
      title,
      message,
      type: type || "info",
      priority: priority || "normal",
      isActive: true,
      createdBy: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true, alertId: alertRef.id};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =====================
// Update alert (Admin only)
// =====================
exports.updateAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  const {alertId, updates} = data;

  try {
    await admin.firestore().collection("alerts").doc(alertId).update({
      ...updates,
      updatedBy: context.auth.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =====================
// Delete/Deactivate alert (Admin only)
// =====================
exports.deleteAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  const {alertId} = data;

  try {
    await admin.firestore().collection("alerts").doc(alertId).update({
      isActive: false,
      deletedBy: context.auth.uid,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =====================
// Get all users (Admin only)
// =====================
exports.getAllUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  try {
    const snapshot = await admin.firestore()
        .collection("users")
        .orderBy("createdAt", "desc")
        .get();

    const users = [];
    snapshot.forEach((doc) => {
      users.push({uid: doc.id, ...doc.data()});
    });

    return {users};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =====================
// Get app statistics (Admin only)
// =====================
exports.getAppStatistics = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admin access required");
  }

  try {
    const [usersSnap, feedbackSnap, routesSnap, alertsSnap] = await Promise.all([
      admin.firestore().collection("users").get(),
      admin.firestore().collection("feedback").get(),
      admin.firestore().collectionGroup("recent_routes").get(),
      admin.firestore().collection("alerts").where("isActive", "==", true).get(),
    ]);

    return {
      totalUsers: usersSnap.size,
      totalFeedback: feedbackSnap.size,
      totalRoutes: routesSnap.size,
      activeAlerts: alertsSnap.size,
    };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});
