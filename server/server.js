// Titik masuk pelayan sebenar. Env: FIREBASE_SERVICE_ACCOUNT (JSON penuh), PORT, HASH_SALT (rawak panjang), DEV_PUBLISH_CODE (pilihan).
const admin = require('firebase-admin');
const { createApp } = require('./app');
if (!process.env.FIREBASE_SERVICE_ACCOUNT) { console.error('RALAT: env FIREBASE_SERVICE_ACCOUNT tiada'); process.exit(1); }
admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
const app = createApp({ admin, db: admin.firestore() });
app.server.listen(process.env.PORT || 8080, () => console.log('EduVerse server siap'));
