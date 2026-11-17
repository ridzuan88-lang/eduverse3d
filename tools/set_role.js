// Tetapkan peranan akaun (jalankan di KOMPUTER ANDA, bukan dalam APK):
//   FIREBASE_SERVICE_ACCOUNT='{...json...}' node tools/set_role.js <e-mel> <super_admin|world_dev|moderator|player>
// Peranan disimpan sebagai Firebase custom claim; pelayan mengesahkannya pada setiap permintaan. Pengguna perlu log masuk semula.
const admin = require('../server/node_modules/firebase-admin');
const [email, role] = process.argv.slice(2);
if (!email || !['super_admin', 'world_dev', 'moderator', 'player'].includes(role)) { console.error('Guna: node tools/set_role.js <e-mel> <super_admin|world_dev|moderator|player>'); process.exit(1); }
admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
(async () => {
  const u = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(u.uid, role === 'player' ? {} : { role });
  console.log(`OK: ${email} -> ${role}. Minta pengguna log keluar & log masuk semula.`);
})().catch((e) => { console.error(e.message); process.exit(1); });
