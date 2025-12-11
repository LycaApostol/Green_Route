const admin = require("firebase-admin");
admin.initializeApp();

// Replace with the UID you want to make admin
const uid = "eubHvCWR3SPBbarDxH4aNQ9PhTD2";

admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log(`Successfully set admin claim for UID: ${uid}`);
    process.exit();
  })
  .catch((error) => {
    console.error("Error setting admin claim:", error);
    process.exit(1);
  });
