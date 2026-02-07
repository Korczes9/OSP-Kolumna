const admin = require('firebase-admin');

// Inicjalizacja Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setPassword() {
  const uid = 'XGQrC30tekcPPJuCNJX5SRILNc32';
  const newPassword = 'M@gda1994';
  
  try {
    await admin.auth().updateUser(uid, {
      password: newPassword
    });
    
    console.log('✅ Hasło zostało zmienione!');
    console.log('\n📋 Dane logowania:');
    console.log('   Email: korczes9@gmail.com');
    console.log('   Hasło: Admin123!');
    console.log('\n⚠️  ZMIEŃ HASŁO po pierwszym zalogowaniu!');
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }
  
  process.exit(0);
}

setPassword();
