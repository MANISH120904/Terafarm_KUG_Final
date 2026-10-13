/**
 * Script to add a test FCM token to a user for testing weather notifications
 * Run this with: node add_test_fcm_token.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/terafarmsih-firebase-adminsdk-w83it-cd1f5d9df1.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addTestFCMToken() {
  try {
    console.log('🔍 Finding a user to add test FCM token...');
    
    // Get first user with location
    const usersSnapshot = await db.collection('users')
      .where('location', '!=', null)
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users with location found');
      process.exit(1);
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log(`\n👤 Selected user: ${userDoc.id}`);
    console.log(`📧 Email: ${userData.email || 'N/A'}`);
    console.log(`📱 Phone: ${userData.phone || 'N/A'}`);
    console.log(`📍 Location: ${JSON.stringify(userData.location)}`);
    
    // Generate a test FCM token (this would normally come from Firebase Messaging)
    // For testing, we'll use a dummy token that follows FCM token format
    const testToken = `dummyFCMToken_${Date.now()}_test123456789`;
    
    console.log(`\n🔑 Adding test FCM token: ${testToken.substring(0, 50)}...`);
    
    // Update user with FCM token
    await db.collection('users').doc(userDoc.id).update({
      fcmToken: testToken,
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Successfully added FCM token to user ${userDoc.id}`);
    console.log(`\n⚠️  NOTE: This is a DUMMY token for testing the query logic.`);
    console.log(`To receive ACTUAL notifications, you need to:`);
    console.log(`1. Run the Flutter app on a real device/emulator`);
    console.log(`2. Initialize Firebase Messaging`);
    console.log(`3. Request notification permission`);
    console.log(`4. Save the real FCM token to Firestore`);
    console.log(`\nSee: lib/services/weather_notification_service.dart`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

addTestFCMToken();
