/**
 * Script to add FCM tokens to existing users for testing
 * This generates dummy FCM tokens so the Cloud Function can find users
 * 
 * Run with: node functions/add_fcm_to_existing_users.js
 */

const admin = require('firebase-admin');

// Initialize with application default credentials
// Make sure you're logged in with: firebase login
admin.initializeApp({
  projectId: 'terafarmsih',
});

const db = admin.firestore();

async function addFCMTokensToUsers() {
  try {
    console.log('🔍 Fetching all users...\n');
    
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users found in database');
      process.exit(1);
    }
    
    console.log(`📊 Found ${usersSnapshot.size} users\n`);
    
    let updated = 0;
    let skipped = 0;
    
    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      
      // Skip if already has FCM token
      if (userData.fcmToken) {
        console.log(`⏭️  Skipping ${doc.id} - already has FCM token`);
        skipped++;
        continue;
      }
      
      // Generate a test FCM token (looks real but won't actually send notifications)
      // Real FCM tokens are 152-163 characters long and start with various prefixes
      const testToken = `cTEST_${doc.id}_${Date.now()}_abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ`;
      
      // Update user with test FCM token
      await db.collection('users').doc(doc.id).update({
        fcmToken: testToken,
        fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        weatherNotificationsEnabled: true, // Enable weather notifications
      });
      
      console.log(`✅ Added FCM token to user: ${doc.id}`);
      console.log(`   Email: ${userData.email || 'N/A'}`);
      console.log(`   Location: ${userData.location ? 'Yes' : 'No'}`);
      console.log(`   Token: ${testToken.substring(0, 50)}...\n`);
      
      updated++;
    }
    
    console.log('\n=================================');
    console.log(`✅ Updated: ${updated} users`);
    console.log(`⏭️  Skipped: ${skipped} users (already had tokens)`);
    console.log('=================================\n');
    
    console.log('⚠️  IMPORTANT NOTES:');
    console.log('1. These are TEST tokens - they won\'t send actual notifications');
    console.log('2. To receive REAL notifications, users must:');
    console.log('   - Login to the Flutter app on a real device');
    console.log('   - Allow notification permissions');
    console.log('   - The app will automatically save their real FCM token');
    console.log('\n3. You can now test the Cloud Function:');
    console.log('   curl "https://asia-south1-terafarmsih.cloudfunctions.net/sendManualWeatherForecast"');
    console.log('\n4. The Cloud Function will:');
    console.log('   - Find users with fcmToken field ✅');
    console.log('   - Try to send notifications (will fail with test tokens)');
    console.log('   - But you can verify the query logic works!\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

addFCMTokensToUsers();
