const admin = require('firebase-admin');

// Initialize with your service account
// Download from Firebase Console > Project Settings > Service Accounts
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// REPLACE WITH YOUR USER'S UID
const uid = 'eubHvCWR3SPBbarDxH4aNQ9PhTD2';

admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log('✅ Admin role assigned!');
    return admin.firestore().collection('users').doc(uid).update({
      role: 'admin',
      isAdmin: true,
    });
  })
  .then(() => {
    console.log('✅ Firestore updated!');
    process.exit();
  })
  .catch(error => {
    console.error('❌ Error:', error);
    process.exit(1);
  });