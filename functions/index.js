const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

admin.initializeApp();

function getSmtpTransport() {
  const smtp = functions.config().smtp || {};
  const host = smtp.host;
  const user = smtp.user;
  const pass = smtp.pass;
  const port = smtp.port ? Number(smtp.port) : 587;
  const secure = smtp.secure === true || smtp.secure === 'true';

  if (!host || !user || !pass) {
    console.log('Brak konfiguracji SMTP. Ustaw: smtp.host, smtp.user, smtp.pass');
    return null;
  }

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });
}

exports.wyslijPrzypomnieniaSzkolen = functions
  .region('europe-central2')
  .pubsub.schedule('every day 07:00')
  .timeZone('Europe/Warsaw')
  .onRun(async () => {
    const transport = getSmtpTransport();
    if (!transport) {
      return null;
    }

    const teraz = new Date();
    const za30 = new Date(teraz.getTime() + 30 * 24 * 60 * 60 * 1000);

    const szkoleniaSnapshot = await admin.firestore()
      .collection('szkolenia')
      .where('dataWaznosci', '>=', admin.firestore.Timestamp.fromDate(teraz))
      .where('dataWaznosci', '<=', admin.firestore.Timestamp.fromDate(za30))
      .get();

    if (szkoleniaSnapshot.empty) {
      console.log('Brak szkoleĹ„ wygasajÄ…cych w ciÄ…gu 30 dni');
      return null;
    }

    const szkolenia = szkoleniaSnapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((s) => !s.powiadomionoEmail30d);

    if (szkolenia.length === 0) {
      console.log('Wszystkie szkolenia zostaĹ‚y juĹĽ oznaczone jako powiadomione');
      return null;
    }

    const strazacySnapshot = await admin.firestore()
      .collection('strazacy')
      .where('aktywny', '==', true)
      .get();

    const strazakMap = new Map();
    const adresy = [];

    strazacySnapshot.docs.forEach((doc) => {
      const data = doc.data();
      const imie = data.imie || '';
      const nazwisko = data.nazwisko || '';
      strazakMap.set(doc.id, `${imie} ${nazwisko}`.trim());

      const role = Array.isArray(data.role)
        ? data.role.map((r) => r.toString())
        : data.rola
          ? [data.rola.toString()]
          : [];

      if ((role.includes('administrator') || role.includes('moderator')) && data.email) {
        adresy.push(data.email);
      }
    });

    if (adresy.length === 0) {
      console.log('Brak adresĂłw email administratorĂłw lub moderatorĂłw');
      return null;
    }

    const linie = szkolenia.map((s) => {
      const strazak = strazakMap.get(s.strazakId) || 'Nieznany straĹĽak';
      const dataWaznosci = s.dataWaznosci?.toDate ? s.dataWaznosci.toDate() : null;
      const dataText = dataWaznosci
        ? dataWaznosci.toISOString().slice(0, 10)
        : 'brak daty';
      return `- ${strazak} | ${s.nazwa || 'Szkolenie'} | waĹĽne do ${dataText}`;
    }).join('\n');

    const smtp = functions.config().smtp || {};
    const fromAddress = smtp.from || smtp.user;

    await transport.sendMail({
      from: fromAddress,
      to: fromAddress,
      bcc: adresy,
      subject: 'Przypomnienie: szkolenia wygasajÄ… w ciÄ…gu 30 dni',
      text: `Szkolenia do odnowienia w ciÄ…gu 30 dni:\n\n${linie}`,
    });

    const batch = admin.firestore().batch();
    szkoleniaSnapshot.docs.forEach((doc) => {
      if (!doc.data().powiadomionoEmail30d) {
        batch.update(doc.ref, {
          powiadomionoEmail30d: true,
          powiadomionoEmail30dO: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
    await batch.commit();

    console.log(`WysĹ‚ano przypomnienia email: ${adresy.length} adresĂłw, ${szkolenia.length} szkoleĹ„`);
    return null;
  });

/**
 * Cloud Function: cotygodniowe sprawdzenie kontroli pojazdĂłw (pon. 08:00)
 * WysyĹ‚a push FCM do konserwatora i kierowcy kat. C / dowĂłdcy.
 */
exports.sprawdzKontrolePojazdu = functions
  .region('europe-central2')
  .pubsub.schedule('every monday 08:00')
  .timeZone('Europe/Warsaw')
  .onRun(async () => {
    const TYDZIEN_MS = 7 * 24 * 60 * 60 * 1000;
    const teraz = new Date();

    // 1. Pobierz wszystkie wozy
    const wozySnap = await admin.firestore().collection('wozy').get();
    if (wozySnap.empty) {
      console.log('Brak wozĂłw w bazie');
      return null;
    }

    // 2. SprawdĹş ostatniÄ… kontrolÄ™ kaĹĽdego wozu
    const wozeBezKontroli = [];

    for (const wozDoc of wozySnap.docs) {
      const woz = wozDoc.data();
      const kontrSnap = await admin.firestore()
        .collection('kontrole_pojazdow')
        .where('wozId', '==', wozDoc.id)
        .get();

      if (kontrSnap.empty) {
        wozeBezKontroli.push(woz.nazwa || wozDoc.id);
        continue;
      }

      // sortuj klientem â€“ najnowsza pierwsza
      const kontrole = kontrSnap.docs
        .map((d) => d.data())
        .sort((a, b) => {
          const da = a.data && a.data.toDate ? a.data.toDate() : new Date(a.data || 0);
          const db = b.data && b.data.toDate ? b.data.toDate() : new Date(b.data || 0);
          return db - da;
        });

      const dataOstatniej = kontrole[0].data && kontrole[0].data.toDate
        ? kontrole[0].data.toDate()
        : new Date(kontrole[0].data || 0);

      if (teraz - dataOstatniej >= TYDZIEN_MS) {
        wozeBezKontroli.push(woz.nazwa || wozDoc.id);
      }
    }

    if (wozeBezKontroli.length === 0) {
      console.log('Wszystkie wozy majÄ… aktualnÄ… kontrolÄ™ â€“ nie wysyĹ‚am przypomnienia');
      return null;
    }

    // 3. ZnajdĹş straĹĽakĂłw do powiadomienia
    const strazacySnap = await admin.firestore()
      .collection('strazacy')
      .where('aktywny', '==', true)
      .get();

    const tokenySet = new Set();

    for (const doc of strazacySnap.docs) {
      const s = doc.data();
      if (!s.fcmToken) continue;

      // dowĂłdca po roli
      const role = (Array.isArray(s.role) ? s.role : s.rola ? [s.rola] : [])
        .map((r) => r.toString().toLowerCase());
      if (role.includes('dowodca') || role.includes('dowĂłdca')) {
        tokenySet.add(s.fcmToken);
        continue;
      }

      // konserwator lub prawo jazdy kat. C po szkoleniach
      const szkSnap = await admin.firestore()
        .collection('szkolenia')
        .where('strazakId', '==', doc.id)
        .get();

      for (const szkDoc of szkSnap.docs) {
        const n = (szkDoc.data().nazwa || '').toLowerCase();
        if (n.includes('konserwator') || (n.includes('prawo jazdy') && n.includes('c'))) {
          tokenySet.add(s.fcmToken);
          break;
        }
      }
    }

    const tokeny = [...tokenySet];
    if (tokeny.length === 0) {
      console.log('Brak tokenĂłw FCM do wysĹ‚ania przypomnieĹ„ o kontroli pojazdu');
      return null;
    }

    const tytul = 'đźš’ Kontrola pojazdu â€“ wymagana!';
    const tresc = wozeBezKontroli.length === 1
      ? `WĂłz ${wozeBezKontroli[0]} wymaga tygodniowej kontroli`
      : `${wozeBezKontroli.length} pojazdy/pojazdĂłw wymagajÄ… kontroli: ${wozeBezKontroli.join(', ')}`;

    await admin.firestore().collection('notifications').add({
      tokens: tokeny,
      title: tytul,
      body: tresc,
      type: 'KONTROLA_POJAZDU',
      data: {
        type: 'KONTROLA_POJAZDU',
        wozy: wozeBezKontroli.join(', '),
      },
      wyslane: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Przypomnienie o kontroli pojazdu wysĹ‚ane do ${tokeny.length} tokenĂłw, wozy: ${wozeBezKontroli.join(', ')}`);
    return null;
  });

/**
 * Cloud Function do wysyĹ‚ania powiadomieĹ„ push
 * NasĹ‚uchuje na nowe dokumenty w kolekcji 'notifications'
 */
exports.wyslijPowiadomienie = functions
  .region('europe-central2')
  .firestore.document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    // JeĹ›li juĹĽ wysĹ‚ane, pomiĹ„
    if (notification.wyslane) {
      return null;
    }

    const tokens = notification.tokens || [];
    if (tokens.length === 0) {
      console.log('Brak tokenĂłw FCM');
      return null;
    }

    let message;

    // Przygotuj wiadomoĹ›Ä‡ w zaleĹĽnoĹ›ci od typu
    if (notification.type === 'ALARM') {
      // Dla ALARMU wysyĹ‚amy zarĂłwno payload "notification" (ĹĽeby system
      // Android sam pokazaĹ‚ gĹ‚oĹ›ne powiadomienie nawet, gdy aplikacja
      // jest ubita/zablokowana), jak i payload "data" do obsĹ‚ugi
      // po stronie klienta.
      const alarmTitle = 'đźš¨ ALARM!';
      const alarmBody = `${notification.kategoria || ''} - ${notification.lokalizacja || ''}`.trim();

      message = {
        notification: {
          title: alarmTitle,
          body: alarmBody,
        },
        data: {
          type: 'ALARM',
          wyjazdId: notification.wyjazdId || '',
          kategoria: notification.kategoria || '',
          lokalizacja: notification.lokalizacja || '',
          opis: notification.opis || '',
          title: alarmTitle,
          body: alarmBody,
          godzina: new Date().toISOString(),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'alarm_channel_v2',
            sound: 'syrena',
            priority: 'PRIORITY_MAX',
          },
        },
      };
    } else if (notification.type === 'WYDARZENIE') {
      const data = notification.dataRozpoczecia?.toDate() || new Date();
      message = {
        notification: {
          title: `đź“… Nowe wydarzenie: ${notification.typWydarzenia}`,
          body: notification.tytul,
        },
        data: {
          type: 'WYDARZENIE',
          wydarzenieId: notification.wydarzenieId || '',
          tytul: notification.tytul || '',
          typWydarzenia: notification.typWydarzenia || '',
        },
      };
    } else if (notification.type === 'PRZYPOMNIENIE') {
      message = {
        notification: {
          title: 'âŹ° Przypomnienie',
          body: `Jutro: ${notification.tytul}`,
        },
        data: {
          type: 'PRZYPOMNIENIE',
          wydarzenieId: notification.wydarzenieId || '',
          tytul: notification.tytul || '',
        },
      };
    } else if (notification.type === 'PRZYPOMNIENIE_WYDARZENIA') {
      const opisDni = notification.opisDni || '';
      const dniDo = notification.dniDo || 0;
      let bodyText;
      if (dniDo === 0) bodyText = `DziĹ›: ${notification.tytul}`;
      else if (dniDo === 1) bodyText = `Jutro: ${notification.tytul}`;
      else bodyText = `Za ${dniDo} dni: ${notification.tytul}`;
      message = {
        notification: {
          title: 'đź“… Nie potwierdzono udziaĹ‚u',
          body: bodyText,
        },
        data: {
          type: 'PRZYPOMNIENIE',
          wydarzenieId: notification.wydarzenieId || '',
          tytul: notification.tytul || '',
          opisDni: opisDni,
        },
        android: {
          notification: {
            channelId: 'terminarz_channel',
          },
        },
      };
    } else if (notification.type === 'IMGW') {
      message = {
        notification: {
          title: notification.title || 'âš ď¸Ź OstrzeĹĽenie IMGW',
          body: notification.body || 'Nowe ostrzeĹĽenie IMGW',
        },
        data: {
          type: 'IMGW',
          id: notification.data?.id || '',
          tytul: notification.data?.tytul || '',
          opis: notification.data?.opis || '',
          poziom: notification.data?.poziom || '',
          dataOd: notification.data?.dataOd || '',
          dataDo: notification.data?.dataDo || '',
          region: notification.data?.region || '',
          typ: notification.data?.typ || '',
        },
      };
    } else if (notification.type === 'discord') {
      // Powiadomienie Discord
      message = {
        notification: {
          title: notification.title || 'đź’¬ Discord',
          body: notification.body || 'Nowa wiadomoĹ›Ä‡ na Discord',
        },
        data: {
          type: 'discord',
          messageId: notification.data?.messageId || '',
          author: notification.data?.author || '',
          channelId: notification.data?.channelId || '',
          kategoria: notification.data?.kategoria || 'Discord',
          fullContent: notification.data?.fullContent || '',
          fullTitle: notification.data?.fullTitle || '',
          fullBody: notification.data?.fullBody || '',
        },
      };
    } else if (notification.type === 'PRZYPOMNIENIE_DOSTEPNOSC') {
      message = {
        notification: {
          title: notification.title || 'đź”” Ustaw dostÄ™pnoĹ›Ä‡',
          body: notification.body || 'UzupeĹ‚nij swojÄ… dostÄ™pnoĹ›Ä‡ na dziĹ› w aplikacji.',
        },
        data: {
          type: 'PRZYPOMNIENIE_DOSTEPNOSC',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'dostepnosc_channel',
          },
        },
      };
    } else if (notification.type === 'AKTUALIZACJA') {
      message = {
        notification: {
          title: notification.title || 'đź”„ DostÄ™pna aktualizacja',
          body: notification.body || 'Nowa wersja aplikacji jest do pobrania.',
        },
        data: {
          type: 'AKTUALIZACJA',
          versionName: notification.data?.versionName || '',
          versionCode: String(notification.data?.versionCode || ''),
          releaseNotes: notification.data?.releaseNotes || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'default_channel',
          },
        },
      };
    } else if (notification.type === 'ZADANIE') {
      message = {
        notification: {
          title: notification.title || 'đź“‹ Zadania',
          body: notification.body || '',
        },
        data: {
          type: 'ZADANIE',
          zadanieId: notification.data?.zadanieId || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'default_channel',
          },
        },
      };
    } else if (notification.type === 'czat') {
      // Powiadomienie z czatu grupowego
      message = {
        notification: {
          title: notification.title || 'đź’¬ Czat jednostki',
          body: notification.body || 'Nowa wiadomoĹ›Ä‡',
        },
        data: {
          type: 'czat',
          authorId: notification.data?.authorId || '',
          authorName: notification.data?.authorName || '',
          body: notification.body || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'czat_channel',
          },
        },
      };
    } else if (notification.type === 'REAKCJA_ALARM') {
      // Reakcja strazaka na alarm - zwykle powiadomienie (NIE alarm!)
      message = {
        notification: {
          title: notification.title || 'Reakcja na alarm',
          body: notification.body || '',
        },
        data: {
          type: 'REAKCJA_ALARM',
          wyjazdId: notification.data?.wyjazdId || '',
          strazakId: notification.data?.strazakId || '',
          status: notification.data?.status || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'default_channel',
          },
        },
      };
    } else if (notification.type === 'LIVE_STATUS') {
      // Status alarmu na zywo - zwykle powiadomienie (NIE alarm!)
      message = {
        notification: {
          title: notification.title || 'Status alarmu',
          body: notification.body || '',
        },
        data: {
          type: 'LIVE_STATUS',
          wyjazdId: notification.data?.wyjazdId || '',
        },
        android: {
          priority: 'default',
          notification: {
            channelId: 'default_channel',
          },
        },
      };
    } else {
      console.log('Nieznany typ powiadomienia:', notification.type);
      return null;
    }

    // WyĹ›lij powiadomienia (do 500 tokenĂłw naraz)
    const batchSize = 500;
    const batches = [];
    
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      batches.push(batch);
    }

    let successCount = 0;
    let failureCount = 0;

    for (const batch of batches) {
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: batch,
          ...message,
        });
        
        successCount += response.successCount;
        failureCount += response.failureCount;
        
        console.log(`WysĹ‚ano: ${response.successCount}, BĹ‚Ä™dy: ${response.failureCount}`);
      } catch (error) {
        console.error('BĹ‚Ä…d wysyĹ‚ania powiadomieĹ„:', error);
        failureCount += batch.length;
      }
    }

    // Oznacz jako wysĹ‚ane
    await snap.ref.update({
      wyslane: true,
      wyslaneDnia: admin.firestore.FieldValue.serverTimestamp(),
      successCount,
      failureCount,
    });

    console.log(`âś… Powiadomienia wysĹ‚ane: ${successCount} sukces, ${failureCount} bĹ‚Ä™dĂłw`);
    return null;
  });

/**
 * Webhook do synchronizacji alarmĂłw z eRemiza
 * 
 * URL: https://europe-central2-[PROJEKT_ID].cloudfunctions.net/synchronizujAlarmZeRemiza
 * 
 * PrzykĹ‚ad requestu z eRemiza:
 * POST /synchronizujAlarmZeRemiza
 * Content-Type: application/json
 * Authorization: Bearer OSP_KOLUMNA_SECRET_2026
 * 
 * Body:
 * {
 *   "id": "ER-2026-001234",
 *   "tytul": "PoĹĽar budynku mieszkalnego",
 *   "opis": "Dym z okna na pierwszym piÄ™trze",
 *   "adres": "ul. GĹ‚Ăłwna 15, Kolumna",
 *   "typ": "pozar",
 *   "data": "2026-01-28T14:30:00Z",
 *   "priorytet": "wysoki"
 * }
 */
exports.synchronizujAlarmZeRemiza = functions
  .region('europe-central2')
  .https.onRequest(async (req, res) => {
    
    // CORS dla testĂłw (opcjonalne)
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }
    
    // SprawdĹş metodÄ™
    if (req.method !== 'POST') {
      return res.status(405).json({ 
        success: false, 
        error: 'Tylko metoda POST' 
      });
    }
    
    // SprawdĹş autoryzacjÄ™
    const authHeader = req.headers['authorization'];
    const expectedToken = 'Bearer OSP_KOLUMNA_SECRET_2026'; // ZMIEĹ na wĹ‚asny tajny klucz!
    
    if (authHeader !== expectedToken) {
      console.warn('Nieautoryzowany dostÄ™p:', authHeader);
      return res.status(401).json({ 
        success: false, 
        error: 'Nieautoryzowany' 
      });
    }
    
    try {
      const alarm = req.body;
      
      // Walidacja danych
      if (!alarm.tytul && !alarm.nazwa) {
        return res.status(400).json({ 
          success: false, 
          error: 'Brak tytuĹ‚u alarmu' 
        });
      }
      
      // Mapowanie kategorii z eRemiza na kategorie w aplikacji
      const mapujKategorie = (typZeRemiza) => {
        const mapping = {
          'pozar': 'pozar',
          'poĹĽar': 'pozar',
          'wypadek': 'wypadek',
          'wypadek_drogowy': 'wypadek',
          'miejscowe': 'miejscowe',
          'miejscowe_zagrozenie': 'miejscowe',
          'false_alarm': 'falszywy',
          'falszywy_alarm': 'falszywy',
          'cwiczenia': 'cwiczenia',
          'Ä‡wiczenia': 'cwiczenia',
        };
        
        const typ = (typZeRemiza || '').toLowerCase();
        return mapping[typ] || 'inne';
      };
      
      // SprawdĹş czy juĹĽ nie istnieje (zapobieganie duplikatom)
      if (alarm.id) {
        const existing = await admin.firestore()
          .collection('wyjazdy')
          .where('eRemizaId', '==', alarm.id)
          .limit(1)
          .get();
        
        if (!existing.empty) {
          console.log('Wyjazd juĹĽ istnieje:', alarm.id);
          return res.status(200).json({ 
            success: true, 
            duplicate: true,
            wyjazdId: existing.docs[0].id,
            message: 'Wyjazd juĹĽ istnieje w bazie' 
          });
        }
      }
      
      // Przygotuj dane wyjazdu
      const wyjazdData = {
        tytul: alarm.tytul || alarm.nazwa || 'Wyjazd z eRemiza',
        opis: alarm.opis || alarm.szczegoly || '',
        lokalizacja: alarm.adres || alarm.lokalizacja || alarm.miejsce || '',
        kategoria: mapujKategorie(alarm.typ),
        dataWyjazdu: alarm.data 
          ? admin.firestore.Timestamp.fromDate(new Date(alarm.data))
          : admin.firestore.Timestamp.now(),
        status: 'aktywny',
        utworzonePrzez: 'SYSTEM_EREMIZA',
        czasTrwaniaGodziny: 0,
        liczbaStrazakow: alarm.liczbaStrazakow || 0,
        zrodlo: 'eRemiza',
        eRemizaId: alarm.id || null,
        priorytet: alarm.priorytet || 'normalny',
        utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Dodaj wyjazd do Firestore
      const wyjazdRef = await admin.firestore()
        .collection('wyjazdy')
        .add(wyjazdData);
      
      console.log(`âś… Dodano wyjazd ${wyjazdRef.id} z eRemiza (ID: ${alarm.id})`);
      
      // Opcjonalnie: WyĹ›lij powiadomienie (jeĹ›li chcesz)
      // await wyslijPowiadomienie(wyjazdRef.id, wyjazdData);
      
      return res.status(200).json({ 
        success: true, 
        wyjazdId: wyjazdRef.id,
        message: 'Wyjazd pomyĹ›lnie dodany',
        data: {
          tytul: wyjazdData.tytul,
          kategoria: wyjazdData.kategoria,
          lokalizacja: wyjazdData.lokalizacja
        }
      });
      
    } catch (error) {
      console.error('âťŚ BĹ‚Ä…d synchronizacji z eRemiza:', error);
      return res.status(500).json({ 
        success: false, 
        error: error.message,
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });
    }
});

/**
 * Webhook do aktualizacji istniejÄ…cych wyjazdĂłw z eRemiza
 * 
 * URL: https://europe-central2-[PROJEKT_ID].cloudfunctions.net/aktualizujWyjazdZeRemiza
 * 
 * PrzykĹ‚ad requestu:
 * POST /aktualizujWyjazdZeRemiza
 * Content-Type: application/json
 * Authorization: Bearer OSP_KOLUMNA_SECRET_2026
 * 
 * Body:
 * {
 *   "id": "ER-2026-001234",
 *   "status": "zakoĹ„czony",
 *   "czasTrwania": 2.5,
 *   "liczbaStrazakow": 12,
 *   "uwagi": "Akcja zakoĹ„czona sukcesem"
 * }
 */
exports.aktualizujWyjazdZeRemiza = functions
  .region('europe-central2')
  .https.onRequest(async (req, res) => {
    
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, PUT, PATCH');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }
    
    if (!['POST', 'PUT', 'PATCH'].includes(req.method)) {
      return res.status(405).json({ 
        success: false, 
        error: 'Tylko metoda POST/PUT/PATCH' 
      });
    }
    
    // Autoryzacja
    const authHeader = req.headers['authorization'];
    const expectedToken = 'Bearer OSP_KOLUMNA_SECRET_2026';
    
    if (authHeader !== expectedToken) {
      return res.status(401).json({ 
        success: false, 
        error: 'Nieautoryzowany' 
      });
    }
    
    try {
      const update = req.body;
      
      if (!update.id) {
        return res.status(400).json({ 
          success: false, 
          error: 'Brak ID wyjazdu z eRemiza' 
        });
      }
      
      // ZnajdĹş wyjazd po eRemizaId
      const snapshot = await admin.firestore()
        .collection('wyjazdy')
        .where('eRemizaId', '==', update.id)
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        console.warn('Nie znaleziono wyjazdu o ID:', update.id);
        return res.status(404).json({ 
          success: false, 
          error: 'Wyjazd nie znaleziony',
          eRemizaId: update.id
        });
      }
      
      const docId = snapshot.docs[0].id;
      const updateData = {};
      
      // Aktualizuj tylko przekazane pola
      if (update.status) {
        updateData.status = update.status === 'zakoĹ„czony' || update.status === 'zakonczone' 
          ? 'zakoĹ„czony' 
          : 'aktywny';
      }
      
      if (update.czasTrwania !== undefined) {
        updateData.czasTrwaniaGodziny = parseFloat(update.czasTrwania) || 0;
      }
      
      if (update.liczbaStrazakow !== undefined) {
        updateData.liczbaStrazakow = parseInt(update.liczbaStrazakow) || 0;
      }
      
      if (update.uwagi) {
        updateData.uwagi = update.uwagi;
      }
      
      // Zawsze dodaj timestamp aktualizacji
      updateData.zaktualizowanoO = admin.firestore.FieldValue.serverTimestamp();
      updateData.zaktualizowaneZeRemiza = true;
      
      // Wykonaj aktualizacjÄ™
      await admin.firestore()
        .collection('wyjazdy')
        .doc(docId)
        .update(updateData);
      
      console.log(`âś… Zaktualizowano wyjazd ${docId} (eRemiza ID: ${update.id})`);
      
      return res.status(200).json({ 
        success: true, 
        wyjazdId: docId,
        message: 'Wyjazd zaktualizowany',
        updated: updateData
      });
      
    } catch (error) {
      console.error('âťŚ BĹ‚Ä…d aktualizacji wyjazdu:', error);
      return res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
});

/**
 * Funkcja testowa - usuĹ„ w produkcji!
 * Pozwala sprawdziÄ‡ czy Cloud Functions dziaĹ‚ajÄ…
 */
exports.testConnection = functions
  .region('europe-central2')
  .https.onRequest((req, res) => {
    res.json({ 
      success: true, 
      message: 'OSP Kolumna Cloud Functions dziaĹ‚ajÄ…!',
      timestamp: new Date().toISOString(),
      region: 'europe-central2'
    });
  });

/**
 * ========================================================================
 * NOWA FUNKCJA: Automatyczna synchronizacja z eRemiza API
 * ========================================================================
 * Odpytuje e-RemizÄ™ co 5 minut i pobiera nowe alarmy
 * Wymaga konfiguracji zmiennych Ĺ›rodowiskowych:
 * - EREMIZA_EMAIL: email do logowania w e-Remiza
 * - EREMIZA_PASSWORD: hasĹ‚o do logowania w e-Remiza
 * 
 * Konfiguracja:
 * firebase functions:config:set eremiza.email="sebastian.grochulski@example.com"
 * firebase functions:config:set eremiza.password="TwojeHaslo123"
 */

/**
 * Generuje JWT token dla API eRemiza
 * Odwzorowanie funkcji gen_jwt z kapi2289/eremiza-api
 */
function generateEremizaJWT(email, password) {
  const payload = {
    email: email,
    password: password,
    iat: Math.floor(Date.now() / 1000)
  };
  
  // eRemiza uĹĽywa prostego JWT bez podpisu (insecure, ale tak dziaĹ‚a ich API)
  return jwt.sign(payload, '', { algorithm: 'none' });
}

/**
 * Klient API eRemiza
 * Bazuje na: https://github.com/kapi2289/eremiza-api
 */
class EremizaClient {
  constructor(email, password) {
    this.email = email;
    this.password = password;
    this.apiUrl = 'https://e-remiza.pl/Terminal';
    this.user = null;
  }

  async _request(method, endpoint, params = null) {
    const jwtToken = generateEremizaJWT(this.email, this.password);
    
    let url = `${this.apiUrl}${endpoint}`;
    if (params) {
      const queryString = new URLSearchParams(params).toString();
      url += `?${queryString}`;
    }

    const response = await fetch(url, {
      method: method,
      headers: {
        'Accept': 'application/json',
        'JWT': jwtToken
      }
    });

    if (!response.ok) {
      throw new Error(`eRemiza API error: ${response.status} ${response.statusText}`);
    }

    return await response.json();
  }

  async login() {
    this.user = await this._request('GET', '/User/GetUser');
    return this.user;
  }

  async getAlarms(count = 10, offset = 0) {
    if (!this.user) {
      await this.login();
    }

    const alarms = await this._request('GET', '/Alarm/GetAlarmList', {
      ouId: this.user.bsisOuId,
      count: count,
      offset: offset
    });

    return alarms;
  }
}

/**
 * Mapuje kategorie z eRemiza do kategorii aplikacji
 * P â†’ poĹĽar
 * Alarm (MZ) â†’ miejscowe zagroĹĽenie
 * Ä† â†’ Ä‡wiczenia
 * PNZR â†’ zabezpieczenie (rejonu JRG Ĺask)
 */
function mapEremizaCategory(subKind) {
  if (!subKind) return 'inne';
  
  const subKindUpper = subKind.toUpperCase().trim();
  
  // DokĹ‚adne mapowanie wedĹ‚ug specyfikacji
  if (subKindUpper === 'P') return 'pozar';
  if (subKindUpper === 'ALARM (MZ)' || subKindUpper === 'MZ') return 'miejscowe';
  if (subKindUpper === 'Ä†' || subKindUpper === 'C') return 'cwiczenia';
  if (subKindUpper === 'PNZR') return 'zabezpieczenie';
  
  // Fallback - czÄ™Ĺ›ciowe dopasowanie
  if (subKindUpper.includes('POĹ»AR') || subKindUpper.includes('POZAR')) return 'pozar';
  if (subKindUpper.includes('WYPADEK')) return 'wypadek';
  if (subKindUpper.includes('MIEJSCOWE')) return 'miejscowe';
  if (subKindUpper.includes('Ä†WICZENIA') || subKindUpper.includes('CWICZENIA')) return 'cwiczenia';
  if (subKindUpper.includes('ZABEZPIECZENIE')) return 'zabezpieczenie';
  if (subKindUpper.includes('FAĹSZYWY') || subKindUpper.includes('FALSZYWY')) return 'falszywy';
  
  return 'inne';
}

/**
 * Sprawdza czy alarm pochodzi z SK KP (Stanowisko Kierowania Komendy Powiatowej)
 */
function isSKKPAlarm(bsisName) {
  if (!bsisName) return false;
  const nameUpper = bsisName.toUpperCase();
  return nameUpper.includes('SK KP') || nameUpper.includes('SK_KP') || nameUpper.includes('SKKP');
}

/**
 * Scheduler uruchamiany co 5 minut
 * Firebase Blaze Plan wymagany (0.10 USD za milion wywoĹ‚aĹ„)
 */
exports.syncEremizaAlarms = functions
  .region('europe-central2')
  .pubsub.schedule('every 5 minutes')
  .timeZone('Europe/Warsaw')
  .onRun(async (context) => {
    console.log('đź”„ Rozpoczynam synchronizacjÄ™ z eRemiza...');

    try {
      // Pobierz dane logowania z Firebase Config
      const email = functions.config().eremiza?.email;
      const password = functions.config().eremiza?.password;

      if (!email || !password) {
        console.error('âťŚ Brak konfiguracji EREMIZA_EMAIL i EREMIZA_PASSWORD');
        console.error('Ustaw zmienne: firebase functions:config:set eremiza.email="..." eremiza.password="..."');
        return null;
      }

      // PoĹ‚Ä…cz z API eRemiza
      const client = new EremizaClient(email, password);
      await client.login();
      console.log(`âś… Zalogowano jako: ${client.user.name || email}`);

      // Pobierz ostatnie 20 alarmĂłw
      const alarms = await client.getAlarms(20, 0);
      console.log(`đź“Ą Pobrano ${alarms.length} alarmĂłw z eRemiza`);

      let addedCount = 0;
      let skippedCount = 0;

      // Przetwarzaj kaĹĽdy alarm
      for (const alarm of alarms) {
        // FILTR: Pomijamy alarmy NIE z SK KP
        if (!isSKKPAlarm(alarm.bsisName)) {
          console.log(`âŹ­ď¸Ź Pomijam alarm spoza SK KP: ${alarm.bsisName || 'brak nazwy'} (ID: ${alarm.id})`);
          skippedCount++;
          continue;
        }

        // SprawdĹş czy alarm juĹĽ istnieje (po ID z eRemiza)
        const existingQuery = await admin.firestore()
          .collection('wyjazdy')
          .where('eRemizaId', '==', alarm.id)
          .limit(1)
          .get();

        if (!existingQuery.empty) {
          console.log(`âŹ­ď¸Ź Pomijam duplikat: ${alarm.id}`);
          skippedCount++;
          continue; // Pomijamy duplikaty
        }

        // Buduj adres
        let lokalizacja = '';
        if (alarm.locality) lokalizacja += alarm.locality.trim();
        if (alarm.street) lokalizacja += (lokalizacja ? ', ' : '') + alarm.street.trim();
        if (alarm.addrPoint) lokalizacja += (lokalizacja ? ' ' : '') + alarm.addrPoint.trim();
        if (alarm.apartment) lokalizacja += '/' + alarm.apartment.trim();

        // Przygotuj dane wyjazdu
        const wyjazdData = {
          tytul: alarm.description || `Alarm ${alarm.subKind || 'nieznany'}`,
          opis: alarm.description || '',
          lokalizacja: lokalizacja || 'Brak lokalizacji',
          kategoria: mapEremizaCategory(alarm.subKind),
          dataWyjazdu: admin.firestore.Timestamp.fromDate(new Date(alarm.aquired)),
          status: 'aktywny',
          utworzonePrzez: 'SYSTEM_EREMIZA',
          czasTrwaniaGodziny: 0,
          zrodlo: 'eRemiza API',
          eRemizaId: alarm.id,
          
          // Dodatkowe dane z eRemiza
          eRemizaData: {
            subKind: alarm.subKind,
            bsisName: alarm.bsisName,
            kind: alarm.kind,
            latitude: alarm.latitude,
            longitude: alarm.longitude,
            locationAccuracy: alarm.locAccuracy,
            notified: alarm.notified || 0,
            confirmed: alarm.confirmed || 0,
            declined: alarm.declined || 0,
            commanders: alarm.commanders || 0,
            drivers: alarm.drivers || 0
          },

          utworzonoO: admin.firestore.FieldValue.serverTimestamp()
        };

        // Dodaj wspĂłĹ‚rzÄ™dne GPS jeĹ›li dostÄ™pne
        if (alarm.latitude && alarm.longitude) {
          wyjazdData.wspolrzedne = {
            lat: alarm.latitude,
            lng: alarm.longitude
          };
        }

        // Zapisz do Firestore
        await admin.firestore().collection('wyjazdy').add(wyjazdData);
        addedCount++;
        
        console.log(`âś… Dodano alarm: ${alarm.id} - ${alarm.description?.substring(0, 50) || 'Brak opisu'}`);
      }

      console.log(`đź“Š Synchronizacja zakoĹ„czona: ${addedCount} dodano, ${skippedCount} pominiÄ™to`);
      return { success: true, added: addedCount, skipped: skippedCount };

    } catch (error) {
      console.error('âťŚ BĹ‚Ä…d synchronizacji z eRemiza:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Funkcja HTTP do rÄ™cznego uruchomienia synchronizacji (do testĂłw)
 * URL: https://europe-central2-[PROJECT_ID].cloudfunctions.net/manualSyncEremiza
 */
exports.manualSyncEremiza = functions
  .region('europe-central2')
  .https.onRequest(async (req, res) => {
    // CORS
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'GET, POST');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      return res.status(204).send('');
    }

    console.log('đź”„ RÄ™czna synchronizacja z eRemiza - rozpoczÄ™ta przez HTTP');

    try {
      const email = functions.config().eremiza?.email;
      const password = functions.config().eremiza?.password;

      if (!email || !password) {
        return res.status(500).json({
          success: false,
          error: 'Brak konfiguracji eRemiza. UĹĽyj: firebase functions:config:set eremiza.email="..." eremiza.password="..."'
        });
      }

      const client = new EremizaClient(email, password);
      await client.login();

      const alarms = await client.getAlarms(20, 0);
      
      let addedCount = 0;
      let skippedCount = 0;

      for (const alarm of alarms) {
        // FILTR: Pomijamy alarmy NIE z SK KP
        if (!isSKKPAlarm(alarm.bsisName)) {
          skippedCount++;
          continue;
        }

        const existingQuery = await admin.firestore()
          .collection('wyjazdy')
          .where('eRemizaId', '==', alarm.id)
          .limit(1)
          .get();

        if (!existingQuery.empty) {
          skippedCount++;
          continue;
        }

        let lokalizacja = '';
        if (alarm.locality) lokalizacja += alarm.locality.trim();
        if (alarm.street) lokalizacja += (lokalizacja ? ', ' : '') + alarm.street.trim();
        if (alarm.addrPoint) lokalizacja += (lokalizacja ? ' ' : '') + alarm.addrPoint.trim();
        if (alarm.apartment) lokalizacja += '/' + alarm.apartment.trim();

        const wyjazdData = {
          tytul: alarm.description || `Alarm ${alarm.subKind || 'nieznany'}`,
          opis: alarm.description || '',
          lokalizacja: lokalizacja || 'Brak lokalizacji',
          kategoria: mapEremizaCategory(alarm.subKind),
          dataWyjazdu: admin.firestore.Timestamp.fromDate(new Date(alarm.aquired)),
          status: 'aktywny',
          utworzonePrzez: 'SYSTEM_EREMIZA',
          czasTrwaniaGodziny: 0,
          zrodlo: 'eRemiza API',
          eRemizaId: alarm.id,
          eRemizaData: {
            subKind: alarm.subKind,
            bsisName: alarm.bsisName,
            kind: alarm.kind,
            latitude: alarm.latitude,
            longitude: alarm.longitude,
            locationAccuracy: alarm.locAccuracy,
            notified: alarm.notified || 0,
            confirmed: alarm.confirmed || 0,
            declined: alarm.declined || 0
          },
          utworzonoO: admin.firestore.FieldValue.serverTimestamp()
        };

        if (alarm.latitude && alarm.longitude) {
          wyjazdData.wspolrzedne = {
            lat: alarm.latitude,
            lng: alarm.longitude
          };
        }

        await admin.firestore().collection('wyjazdy').add(wyjazdData);
        addedCount++;
      }

      return res.status(200).json({
        success: true,
        message: `Synchronizacja zakoĹ„czona: ${addedCount} dodano, ${skippedCount} pominiÄ™to`,
        added: addedCount,
        skipped: skippedCount,
        total: alarms.length
      });

    } catch (error) {
      console.error('âťŚ BĹ‚Ä…d:', error);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

/**
 * Cron job wysyĹ‚ajÄ…cy przypomnienia o wydarzeniach (uruchamiany codziennie)
 * WysyĹ‚a przypomnienia 1 dzieĹ„ przed wydarzeniem o godz. 18:00
 */
/**
 * WysyĹ‚a przypomnienie o dostÄ™pnoĹ›ci do kaĹĽdego straĹĽaka o jego indywidualnej
 * godzinie (pola reminderGodzina / reminderMinuta w dokumencie strazacy).
 * DomyĹ›lna godzina to 8:00, gdy straĹĽak nie ustawiĹ‚ wĹ‚asnej.
 * Funkcja sprawdza co 15 minut, czy czyjaĹ› godzina przypada w bieĹĽÄ…cym oknie.
 */
exports.cyklicznyReminderDostepnosci = functions
  .region('europe-central2')
  .pubsub.schedule('every 15 minutes')
  .timeZone('Europe/Warsaw')
  .onRun(async () => {
    const now = new Date();
    // Przeliczymy na strefÄ™ Europe/Warsaw bezpiecznie przez formatowanie
    const warsawStr = now.toLocaleString('en-US', { timeZone: 'Europe/Warsaw' });
    const warsawTime = new Date(warsawStr);
    const currentHour = warsawTime.getHours();
    const currentMinute = warsawTime.getMinutes();
    // Aktualny 15-minutowy przedziaĹ‚: 0, 15, 30 lub 45
    const currentSlot = Math.floor(currentMinute / 15) * 15;

    console.log(`[cyklicznyReminder] ${currentHour}:${String(currentSlot).padStart(2, '0')} (Warsaw)`);

    try {
      const strazacySnapshot = await admin.firestore()
        .collection('strazacy')
        .where('aktywny', '==', true)
        .get();

      const tokens = [];
      for (const doc of strazacySnapshot.docs) {
        const data = doc.data();
        const reminderHour = data.reminderGodzina ?? 8;
        const reminderMinute = data.reminderMinuta ?? 0;
        const reminderSlot = Math.floor(reminderMinute / 15) * 15;
        if (reminderHour === currentHour && reminderSlot === currentSlot) {
          const token = data.fcmToken;
          if (token && token.length > 0) {
            tokens.push(token);
          }
        }
      }

      if (tokens.length === 0) {
        console.log(`Brak straĹĽakĂłw do przypomnienia o ${currentHour}:${String(currentSlot).padStart(2, '0')}`);
        return null;
      }

      await admin.firestore().collection('notifications').add({
        tokens,
        type: 'PRZYPOMNIENIE_DOSTEPNOSC',
        title: 'đź”” Ustaw dostÄ™pnoĹ›Ä‡',
        body: 'UzupeĹ‚nij swojÄ… dostÄ™pnoĹ›Ä‡ na dziĹ› w aplikacji.',
        data: { type: 'PRZYPOMNIENIE_DOSTEPNOSC' },
        utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
        wyslane: false,
      });

      console.log(`WysĹ‚ano przypomnienie do ${tokens.length} straĹĽakĂłw o ${currentHour}:${String(currentSlot).padStart(2, '0')}`);
      return null;
    } catch (error) {
      console.error('BĹ‚Ä…d cyklicznego przypomnienia dostÄ™pnoĹ›ci:', error);
      return null;
    }
  });

/**
 * O pĂłĹ‚nocy resetuje status dostÄ™pnoĹ›ci wszystkich aktywnych straĹĽakĂłw
 * na "brak reakcji". KaĹĽdy straĹĽak dostanie potem powiadomienie
 * o wĹ‚asnej godzinie (cyklicznyReminderDostepnosci).
 */
exports.resetujDostepnosc = functions
  .region('europe-central2')
  .pubsub.schedule('1 0 * * *') // Codziennie o 00:01 czasu PL
  .timeZone('Europe/Warsaw')
  .onRun(async () => {
    console.log('âŹ° Reset dostÄ™pnoĹ›ci o pĂłĹ‚nocy - start');
    try {
      const strazacySnapshot = await admin.firestore()
        .collection('strazacy')
        .where('aktywny', '==', true)
        .get();

      const batch = admin.firestore().batch();
      const teraz = new Date();
      let pominietych = 0;
      strazacySnapshot.docs.forEach((doc) => {
        const data = doc.data();
        // Pomijaj straĹĽakĂłw na urlopie
        const urlopDo = data.urlopDo;
        if (urlopDo) {
          const dataUrlopu = urlopDo.toDate ? urlopDo.toDate() : new Date(urlopDo);
          if (dataUrlopu > teraz) {
            pominietych++;
            return; // Na urlopie â€” nie resetuj
          }
        }
        batch.update(doc.ref, {
          brakReakcji: true,
          dostepny: false,
        });
      });
      await batch.commit();
      console.log(`âś… Reset dostÄ™pnoĹ›ci dla ${strazacySnapshot.size - pominietych} straĹĽakĂłw (pominiÄ™to ${pominietych} na urlopie)`);
      return null;
    } catch (error) {
      console.error('âťŚ BĹ‚Ä…d resetu dostÄ™pnoĹ›ci:', error);
      return null;
    }
  });

exports.wyslijPrzypomnienia = functions
  .region('europe-central2')
  .pubsub.schedule('0 18 * * *') // Codziennie o 18:00
  .timeZone('Europe/Warsaw')
  .onRun(async (context) => {
    console.log('Sprawdzanie nadchodzÄ…cych wydarzeĹ„...');

    const jutro = new Date();
    jutro.setDate(jutro.getDate() + 1);
    jutro.setHours(0, 0, 0, 0);

    const pojutrze = new Date(jutro);
    pojutrze.setDate(pojutrze.getDate() + 1);

    try {
      const wydarzeniaSnapshot = await admin.firestore()
        .collection('wydarzenia')
        .where('dataRozpoczecia', '>=', admin.firestore.Timestamp.fromDate(jutro))
        .where('dataRozpoczecia', '<', admin.firestore.Timestamp.fromDate(pojutrze))
        .where('widoczneDlaWszystkich', '==', true)
        .get();

      console.log(`Znaleziono ${wydarzeniaSnapshot.size} wydarzeĹ„ na jutro`);

      for (const doc of wydarzeniaSnapshot.docs) {
        const wydarzenie = doc.data();
        
        // Pobierz tokeny wszystkich aktywnych straĹĽakĂłw
        const strazacySnapshot = await admin.firestore()
          .collection('strazacy')
          .where('aktywny', '==', true)
          .get();

        const tokens = strazacySnapshot.docs
          .map(d => d.data().fcmToken)
          .filter(token => token && token.length > 0);

        if (tokens.length > 0) {
          await admin.firestore().collection('notifications').add({
            type: 'PRZYPOMNIENIE',
            wydarzenieId: doc.id,
            tytul: wydarzenie.tytul,
            typWydarzenia: wydarzenie.typ,
            dataRozpoczecia: wydarzenie.dataRozpoczecia,
            tokens: tokens,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            wyslane: false,
          });

          console.log(`Dodano przypomnienie dla wydarzenia: ${wydarzenie.tytul}`);
        }
      }

      console.log('âś… Przypomnienia dodane do kolejki');
      return null;
    } catch (error) {
      console.error('BĹ‚Ä…d wysyĹ‚ania przypomnieĹ„:', error);
      return null;
    }
  });

/**
 * Cloud Function do wysyĹ‚ania powiadomieĹ„ Discord
 * NasĹ‚uchuje na nowe dokumenty w kolekcji 'powiadomienia'
 */
exports.wyslijPowiadomienieDiscord = functions
  .region('europe-central2')
  .firestore.document('powiadomienia/{powiadomienieId}')
  .onCreate(async (snap, context) => {
    const powiadomienie = snap.data();
    
    // JeĹ›li juĹĽ wysĹ‚ane, pomiĹ„
    if (powiadomienie.wyslane) {
      console.log('Powiadomienie juĹĽ wysĹ‚ane, pomijam');
      return null;
    }

    const tokens = powiadomienie.tokens || [];
    if (tokens.length === 0) {
      console.log('Brak tokenĂłw FCM');
      await snap.ref.update({ wyslane: true });
      return null;
    }

    const type = powiadomienie.data?.type || 'discord';
    const isAlarmType = type === 'ALARM';
    
    // FCM ma limit 256 znakow dla notification.body - skroc jesli potrzeba
    const maxBodyLength = 200;
    let bodyText = powiadomienie.body || 'Nowa wiadomosc';
    if (bodyText.length > maxBodyLength) {
      bodyText = bodyText.substring(0, maxBodyLength - 3) + '...';
    }
    
    // Przygotuj wiadomosc FCM
    const message = {
      notification: {
        title: powiadomienie.title || (isAlarmType ? '=� ALARM!' : '=� Discord'),
        body: bodyText,
      },
      data: {
        type: type,
        wyjazdId: powiadomienie.data?.wyjazdId || '',
        messageId: powiadomienie.data?.messageId || '',
        author: powiadomienie.data?.author || '',
        channelId: powiadomienie.data?.channelId || '',
        fullContent: powiadomienie.data?.fullContent || '',
        fullTitle: powiadomienie.data?.fullTitle || '',
        fullBody: powiadomienie.data?.fullBody || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: isAlarmType ? 'syrena' : 'default',
          channelId: isAlarmType ? 'alarm_channel_v2' : 'discord_channel',
          priority: isAlarmType ? 'PRIORITY_MAX' : 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: isAlarmType ? 'syrena.caf' : 'default',
            badge: 1,
          },
        },
      },
    };

    // WyĹ›lij powiadomienia w batch'ach (do 500 tokenĂłw naraz)
    const batchSize = 500;
    let successCount = 0;
    let failureCount = 0;

    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      
      try {
        const response = await admin.messaging().sendEachForMulticast({
          ...message,
          tokens: batch,
        });

        successCount += response.successCount;
        failureCount += response.failureCount;

        // UsuĹ„ nieprawidĹ‚owe tokeny
        if (response.failureCount > 0) {
          const tokensToRemove = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const error = resp.error;
              if (error.code === 'messaging/invalid-registration-token' ||
                  error.code === 'messaging/registration-token-not-registered') {
                tokensToRemove.push(batch[idx]);
              }
            }
          });

          // UsuĹ„ nieprawidĹ‚owe tokeny z bazy
          for (const token of tokensToRemove) {
            const userSnapshot = await admin.firestore()
              .collection('strazacy')
              .where('fcmToken', '==', token)
              .get();
            
            for (const doc of userSnapshot.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
            }
          }
          
          console.log(`UsuniÄ™to ${tokensToRemove.length} nieprawidĹ‚owych tokenĂłw`);
        }
      } catch (error) {
        console.error(`BĹ‚Ä…d wysyĹ‚ania batch ${i / batchSize + 1}:`, error);
        failureCount += batch.length;
      }
    }

    console.log(`âś… WysĹ‚ano powiadomienia Discord: ${successCount} sukces, ${failureCount} bĹ‚Ä…d`);

    // Oznacz jako wysĹ‚ane
    await snap.ref.update({ 
      wyslane: true,
      successCount: successCount,
      failureCount: failureCount,
      wyslanoO: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });

/**
 * Cloud Function â€“ codzienna wysyĹ‚ka przypomnieĹ„ o wydarzeniach
 * dla uĹĽytkownikĂłw z brakiem decyzji (null / jeszcze nie wiem).
 * Uruchamia siÄ™ codziennie o 9:00 polskiego czasu.
 * WysyĹ‚a powiadomienia tylko gdy do wydarzenia <= 14 dni.
 */
exports.wyslijCodzienneReminderywydarzenia = functions
  .region('europe-central2')
  .pubsub.schedule('every day 09:00')
  .timeZone('Europe/Warsaw')
  .onRun(async () => {
    const teraz = new Date();
    const za14dni = new Date(teraz.getTime() + 14 * 24 * 60 * 60 * 1000);

    const snapshot = await admin.firestore()
      .collection('remindery_wydarzen')
      .where('aktywne', '==', true)
      .where('dataWydarzenia', '>=', admin.firestore.Timestamp.fromDate(teraz))
      .where('dataWydarzenia', '<=', admin.firestore.Timestamp.fromDate(za14dni))
      .get();

    if (snapshot.empty) {
      console.log('Brak aktywnych przypomnieĹ„ wydarzeĹ„ w ciÄ…gu 14 dni');
      return null;
    }

    // Pobierz tokeny FCM dla unikalnych userId (batch po 10 â€“ limit Firestore)
    const userIds = [...new Set(snapshot.docs.map((d) => d.data().userId))];
    const strazacyMap = new Map();
    for (let i = 0; i < userIds.length; i += 10) {
      const chunk = userIds.slice(i, i + 10);
      const strazacySnap = await admin.firestore()
        .collection('strazacy')
        .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
        .get();
      strazacySnap.docs.forEach((doc) => {
        const fcmToken = doc.data().fcmToken;
        if (fcmToken) strazacyMap.set(doc.id, fcmToken);
      });
    }

    const batch = admin.firestore().batch();
    let zaszeregowano = 0;

    for (const doc of snapshot.docs) {
      const reminder = doc.data();
      const fcmToken = strazacyMap.get(reminder.userId);
      if (!fcmToken) continue;

      const dataWydarzenia = reminder.dataWydarzenia.toDate();
      // Oblicz peĹ‚ne dni â€“ ignorujÄ…c godziny
      const dzisiaj = new Date(teraz.getFullYear(), teraz.getMonth(), teraz.getDate());
      const dzienWydarzenia = new Date(
        dataWydarzenia.getFullYear(),
        dataWydarzenia.getMonth(),
        dataWydarzenia.getDate()
      );
      const dniDo = Math.round((dzienWydarzenia - dzisiaj) / (24 * 60 * 60 * 1000));

      const notifRef = admin.firestore().collection('notifications').doc();
      batch.set(notifRef, {
        type: 'PRZYPOMNIENIE_WYDARZENIA',
        tokens: [fcmToken],
        wydarzenieId: reminder.wydarzenieId,
        tytul: reminder.tytulWydarzenia,
        opisDni: dniDo === 0 ? 'dziĹ›' : dniDo === 1 ? 'jutro' : `za ${dniDo} dni`,
        dniDo,
        dataRozpoczecia: reminder.dataWydarzenia,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      zaszeregowano++;
    }

    await batch.commit();
    console.log(`đź“… WysĹ‚ano ${zaszeregowano} przypomnieĹ„ o wydarzeniach`);
    return null;
  });

/**
 * Gdy admin wgra nowÄ… wersjÄ™ APK (upload_update.js aktualizuje app_config/latest_version),
 * automatycznie wysyĹ‚a powiadomienie FCM do wszystkich aktywnych straĹĽakĂłw.
 */
exports.powiadomOAktualizacji = functions
  .region('europe-central2')
  .firestore.document('app_config/latest_version')
  .onWrite(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();

    if (!after) return null;

    // Reaguj tylko na zmianÄ™ versionCode (nowa wersja), nie na pierwsze tworzenie dokumentu
    const newCode = after.versionCode;
    const oldCode = before ? before.versionCode : null;
    if (oldCode !== null && newCode === oldCode) return null;

    console.log(`đź”„ Nowa wersja: ${after.versionName} (build ${newCode})`);

    try {
      const strazacySnapshot = await admin.firestore()
        .collection('strazacy')
        .where('aktywny', '==', true)
        .get();

      const tokens = strazacySnapshot.docs
        .map((d) => d.data().fcmToken)
        .filter((token) => token && token.length > 0);

      if (tokens.length === 0) {
        console.log('Brak tokenĂłw FCM do powiadomienia o aktualizacji');
        return null;
      }

      await admin.firestore().collection('notifications').add({
        tokens,
        type: 'AKTUALIZACJA',
        title: 'đź”„ DostÄ™pna aktualizacja',
        body: `Nowa wersja ${after.versionName} jest do pobrania.`,
        data: {
          type: 'AKTUALIZACJA',
          versionName: after.versionName || '',
          versionCode: String(newCode || ''),
          releaseNotes: after.releaseNotes || '',
        },
        utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
        wyslane: false,
      });

      console.log(`âś… Powiadomienie o aktualizacji zakolejkowane (${tokens.length} tokenĂłw)`);
      return null;
    } catch (error) {
      console.error('âťŚ BĹ‚Ä…d powiadomienia o aktualizacji:', error);
      return null;
    }
  });

// â”€â”€â”€ POMOCNIK: odlegĹ‚oĹ›Ä‡ haversine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/**
 * Oblicza odlegĹ‚oĹ›Ä‡ w metrach miÄ™dzy dwoma punktami GPS metodÄ… haversine.
 */
function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371000; // promieĹ„ Ziemi w metrach
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// WspĂłĹ‚rzÄ™dne remizy OSP Kolumna
const REMIZA_LAT = 51.6053;
const REMIZA_LON = 19.1867;
const PROMIEN_REMIZY = 200; // metry

/**
 * Reaguje na aktualizacjÄ™ lokalizacji straĹĽaka w Firestore.
 * Gdy straĹĽak przybywa w promieĹ„ remizy (< 200m), wysyĹ‚a powiadomienie do adminĂłw.
 */
exports.sprawdzLokalizacjeStrazaka = functions
  .region('europe-central2')
  .firestore.document('strazacy/{strazakId}')
  .onUpdate(async (change, context) => {
    const przed = change.before.data();
    const po = change.after.data();

    // SprawdĹş czy lokalizacja jest aktywna i czy wspĂłĹ‚rzÄ™dne siÄ™ zmieniĹ‚y
    if (!po.lokalizacjaAktywna) return null;
    if (po.lastLat === przed.lastLat && po.lastLon === przed.lastLon) return null;
    if (!po.lastLat || !po.lastLon) return null;

    const dystans = haversine(po.lastLat, po.lastLon, REMIZA_LAT, REMIZA_LON);
    const bylWRemizie = przed.wRemizie === true;
    const jestWRemizie = dystans <= PROMIEN_REMIZY;

    // Aktualizuj flagÄ™ wRemizie jeĹ›li siÄ™ zmieniĹ‚a
    if (jestWRemizie !== bylWRemizie) {
      await change.after.ref.update({ wRemizie: jestWRemizie });
    }

    // WyĹ›lij powiadomienie gdy straĹĽak PRZYBYWA do remizy (flip falseâ†’true)
    // Wykryj WYJAZD: strazak oddal sie od remizy (flip true->false)
    if (!jestWRemizie && bylWRemizie) {
      try {
        const poza = await admin.firestore()
          .collection('strazacy')
          .where('aktywny', '==', true)
          .where('lokalizacjaAktywna', '==', true)
          .where('wRemizie', '==', false)
          .get();
        const liczbaOddalonych = poza.size;
        if (liczbaOddalonych >= 2) {
          const configRef = admin.firestore().doc('config/wyjazd_live');
          const configDoc = await configRef.get();
          const ostatniaLiczba = configDoc.exists ? (configDoc.data().ostatniaLiczbaOddalonych || 0) : 0;
          if (liczbaOddalonych > ostatniaLiczba) {
            await configRef.set({ ostatniaLiczbaOddalonych: liczbaOddalonych }, { merge: true });
            const wszystkieTokeny = await pobierzTokenyWszystkich();
            if (wszystkieTokeny.length > 0) {
              await wyslijFCMLive(
                'ALARM',
                'Wyjechalismy!',
                `${liczbaOddalonych} strazakow w drodze na akcje`,
                wszystkieTokeny,
                { typ: 'WYJAZD_POTWIERDZONY', liczba: String(liczbaOddalonych) }
              );
            }
          }
        }
      } catch (e) {
        console.error('Blad wykrywania wyjazdu:', e);
      }
    }

    if (jestWRemizie && !bylWRemizie) {
      const imie = po.imie || '';
      const nazwisko = po.nazwisko || '';
      const pelneImie = `${imie} ${nazwisko}`.trim() || 'StraĹĽak';
      console.log(`đź“Ť ${pelneImie} przybyĹ‚ do remizy (${Math.round(dystans)}m)`);

      try {
        // Pobierz tokeny administratorĂłw
        const adminiSnapshot = await admin.firestore()
          .collection('strazacy')
          .where('aktywny', '==', true)
          .where('administrator', '==', true)
          .get();

        const tokens = adminiSnapshot.docs
          .map((d) => d.data().fcmToken)
          .filter((t) => t && t.length > 0);

        if (tokens.length === 0) {
          console.log('Brak tokenĂłw adminĂłw do powiadomienia o lokalizacji');
          return null;
        }

        await admin.firestore().collection('notifications').add({
          tokens,
          type: 'LOKALIZACJA_REMIZA',
          title: 'đźŹ  StraĹĽak w remizie',
          body: `${pelneImie} przybyĹ‚ do remizy`,
          data: {
            type: 'LOKALIZACJA_REMIZA',
            strazakId: context.params.strazakId,
            pelneImie,
          },
          utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
          wyslane: false,
        });

        console.log(`âś… Powiadomienie o przybyciu wysĹ‚ane do ${tokens.length} adminĂłw`);
      } catch (error) {
        console.error('âťŚ BĹ‚Ä…d powiadomienia o lokalizacji:', error);
      }
    }

    // --- STATUS LIVE: aktywny alarm przez 30 minut od startu ---
    try {
      const dwiePrzed = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 60 * 60 * 1000);
      const wyjazdySnap = await admin.firestore()
        .collection('wyjazdy')
        .where('dataWyjazdu', '>', dwiePrzed)
        .get();

      const aktywne = wyjazdySnap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((w) => w.status === 'aktywny')
        .sort((a, b) => {
          const ta = a.dataWyjazdu?.toMillis?.() || 0;
          const tb = b.dataWyjazdu?.toMillis?.() || 0;
          return tb - ta;
        });

      if (aktywne.length > 0) {
        const alarm = aktywne[0];
        const alarmStart = alarm.dataWyjazdu?.toMillis?.() || alarm.utworzonoO?.toMillis?.() || 0;

        if (Date.now() - alarmStart <= 30 * 60 * 1000) {
          const alarmLat = alarm.wspolrzedne?.lat;
          const alarmLon = alarm.wspolrzedne?.lng;
          const strazakId = context.params.strazakId;

          if (przed.lastLat && przed.lastLon && po.lastLat && po.lastLon) {
            const dystPrzed = haversine(przed.lastLat, przed.lastLon, REMIZA_LAT, REMIZA_LON);
            const dystPo = haversine(po.lastLat, po.lastLon, REMIZA_LAT, REMIZA_LON);
            // jedzie do remizy: odleglosc od remizy maleje, jeszcze nie dotarl
            const kieruje = dystPo < dystPrzed && !jestWRemizie && dystPo > 80;
            await admin.firestore().collection('alarm_live').doc(strazakId).set({
              kieruje,
              wyjazdId: alarm.id,
              ts: Date.now(),
            });
          }

          const strazacySnap = await admin.firestore()
            .collection('strazacy')
            .where('aktywny', '==', true)
            .where('lokalizacjaAktywna', '==', true)
            .get();

          let liczbaWRemizie = 0;
          let liczbaPoza = 0;
          strazacySnap.docs.forEach((d) => {
            if (d.data().wRemizie) liczbaWRemizie++;
            else liczbaPoza++;
          });

          const alarmLiveSnap = await admin.firestore().collection('alarm_live').get();
          const teraz2 = Date.now();
          const liczbaJedzie = alarmLiveSnap.docs.filter((d) => {
            const ad = d.data();
            return ad.wyjazdId === alarm.id && ad.kieruje === true && teraz2 - (ad.ts || 0) < 5 * 60 * 1000;
          }).length;

          const liveRef = admin.firestore().doc('config/wyjazd_live');
          const liveDoc = await liveRef.get();
          const ostatniStatus = liveDoc.exists ? (liveDoc.data().ostatniStatusLive || {}) : {};

          if (
            ostatniStatus.wRemizie !== liczbaWRemizie ||
            ostatniStatus.poza !== liczbaPoza ||
            ostatniStatus.jedzie !== liczbaJedzie
          ) {
            await liveRef.set({
              ostatniStatusLive: { wRemizie: liczbaWRemizie, poza: liczbaPoza, jedzie: liczbaJedzie },
            }, { merge: true });

            // Tokeny tylko strazakow co klikneli "jade"
            const odpowiedziSnap = await admin.firestore()
              .collection('wyjazdy')
              .doc(alarm.id)
              .collection('odpowiedzi')
              .where('status', '==', 'jade')
              .get();
            const jadacyIds = odpowiedziSnap.docs.map((d) => d.id);
            if (jadacyIds.length > 0) {
              const strazacyJadaSnap = await admin.firestore()
                .collection('strazacy')
                .where('aktywny', '==', true)
                .get();
              const tokenyJadacych = strazacyJadaSnap.docs
                .filter((d) => jadacyIds.includes(d.id))
                .map((d) => d.data().fcmToken)
                .filter((t) => t && t.length > 0);
              if (tokenyJadacych.length > 0) {
                const tytulAlarmu = alarm.tytul || 'Alarm aktywny';
                await wyslijFCMLive(
                  'LIVE_STATUS',
                  'Alarm: ' + tytulAlarmu,
                  'W remizie: ' + liczbaWRemizie + ' | Wyjechalo: ' + liczbaPoza + ' | Jedzie: ' + liczbaJedzie,
                  tokenyJadacych,
                  {
                    typ: 'LIVE_STATUS',
                    wyjazdId: alarm.id,
                    wRemizie: String(liczbaWRemizie),
                    poza: String(liczbaPoza),
                    jedzie: String(liczbaJedzie),
                  }
                );
              }
            }
          }
        }
      }
    } catch (e) {
      console.error('Blad live status alarmu:', e);
    }

    return null;
  });

// ============================================================================
// LIVE TRIGGERY - reaguja na nowe dokumenty w Firestore i wysylaja FCM
// ============================================================================

/**
 * Helper: pobiera tokeny FCM wszystkich aktywnych strazakow
 */
async function pobierzTokenyWszystkich() {
  const snap = await admin.firestore()
    .collection('strazacy')
    .where('aktywny', '==', true)
    .get();
  const tokeny = [];
  snap.docs.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (token) tokeny.push(token);
  });
  return tokeny;
}

/**
 * Helper: wysyla powiadomienie przez kolejke notifications
 */
async function wyslijFCMLive(type, title, body, tokens, extraData = {}) {
  if (tokens.length === 0) return;
  await admin.firestore().collection('notifications').add({
    type,
    title,
    body,
    tokens,
    data: extraData,
    utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
    wyslane: false,
  });
}

/**
 * Pobiera alarmy z e-Remiza i importuje nowe do Firestore.
 * Uruchamia sie co 5 minut.
 */
const cheerio = require('cheerio');

exports.pobierzAlarmy = functions
  .region('europe-central2')
  .pubsub.schedule('every 5 minutes')
  .onRun(async () => {
    try {
      // Wczytaj credentials z Firestore
      const cfgDoc = await admin.firestore().collection('config').doc('eremiza').get();
      if (!cfgDoc.exists || !cfgDoc.data().aktywne) {
        console.log('pobierzAlarmy: wylaczone lub brak konfiguracji');
        return null;
      }
      const { login, haslo } = cfgDoc.data();

      // === KROK 1: Pobierz token CSRF ze strony logowania ===
      const cookieJar = {};

      const saveCookies = (response) => {
        const raw = response.headers.raw()['set-cookie'] || [];
        raw.forEach((c) => {
          const part = c.split(';')[0];
          const [k, v] = part.split('=');
          if (k && v !== undefined) cookieJar[k.trim()] = v.trim();
        });
      };

      const cookieHeader = () =>
        Object.entries(cookieJar).map(([k, v]) => `${k}=${v}`).join('; ');

      const loginPageRes = await fetch('https://e-remiza.pl/OSP.UI.SSO/logowanie', {
        headers: { 'User-Agent': 'Mozilla/5.0' },
      });
      saveCookies(loginPageRes);
      const loginHtml = await loginPageRes.text();
      const $l = cheerio.load(loginHtml);

      // Znajdz token CSRF (ASP.NET __RequestVerificationToken lub podobny)
      const csrfToken = $l('input[name="__RequestVerificationToken"]').val() || '';

      // === KROK 2: Zaloguj sie ===
      const formBody = new URLSearchParams({
        Email: login,
        Password: haslo,
        __RequestVerificationToken: csrfToken,
      });

      const loginRes = await fetch('https://e-remiza.pl/OSP.UI.SSO/logowanie', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0',
          Cookie: cookieHeader(),
        },
        body: formBody.toString(),
        redirect: 'manual',
      });
      saveCookies(loginRes);

      // Sprawdz czy zalogowany (przekierowanie po zalogowaniu)
      if (loginRes.status !== 302 && loginRes.status !== 200) {
        console.error('pobierzAlarmy: blad logowania, status', loginRes.status);
        return null;
      }

      // === KROK 3: Pobierz liste alarmow ===
      const alarmsRes = await fetch('https://e-remiza.pl/OSP.UI.EREMIZA/alarmy', {
        headers: {
          'User-Agent': 'Mozilla/5.0',
          Cookie: cookieHeader(),
        },
      });
      saveCookies(alarmsRes);

      if (alarmsRes.status !== 200) {
        console.error('pobierzAlarmy: brak dostepu do alarmow, status', alarmsRes.status);
        return null;
      }

      const alarmsHtml = await alarmsRes.text();
      const $ = cheerio.load(alarmsHtml);

      // === KROK 4: Parsuj tabele alarmow ===
      const alarmy = [];
      $('table tr').each((i, row) => {
        if (i === 0) return; // pomijaj naglowek
        const cols = $(row).find('td');
        if (cols.length < 3) return;

        const czasStr = $(cols[0]).text().trim();
        const rodzaj = $(cols[1]).text().trim();
        const miejsceZdarzenia = $(cols[2]).text().trim();
        const opis = cols.length > 3 ? $(cols[3]).text().trim() : '';

        if (!czasStr) return;

        // Filtruj tylko SK KP (Straz Pozarna / Komendy Powiatowej)
        // Wkluczamy: MZ (miejscowe zagrozenie), Alarm, wszystkie typy
        // Jesli chcesz tylko SKKP - odkomentuj:
        // if (!rodzaj.includes('SK') && !rodzaj.includes('KP')) return;

        alarmy.push({ czasStr, rodzaj, miejsceZdarzenia, opis });
      });

      console.log(`pobierzAlarmy: znaleziono ${alarmy.length} alarmow`);

      if (alarmy.length === 0) return null;

      // === KROK 5: Importuj nowe alarmy do Firestore ===
      let importowanych = 0;
      for (const alarm of alarmy) {
        // Parsuj date: format "DD-MM-YYYY HH:MM"
        const dtMatch = alarm.czasStr.match(/(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2})/);
        if (!dtMatch) continue;
        const [, dd, mm, yyyy, hh, min] = dtMatch;
        const dataAlarmu = new Date(`${yyyy}-${mm}-${dd}T${hh}:${min}:00`);

        // Unikalny klucz: data + miejsce
        const eremizaId = `eremiza_${yyyy}${mm}${dd}_${hh}${min}_${alarm.miejsceZdarzenia.replace(/\s+/g, '_').substring(0, 30)}`;

        // Sprawdz czy juz istnieje
        const existing = await admin.firestore()
          .collection('wyjazdy')
          .where('eremizaId', '==', eremizaId)
          .limit(1)
          .get();

        if (!existing.empty) continue;

        // Pomijaj alarmy starsze niz 2 godziny
        const wiek = Date.now() - dataAlarmu.getTime();
        if (wiek > 2 * 60 * 60 * 1000) continue;

        // Dodaj wyjazd do Firestore
        const docRef = await admin.firestore().collection('wyjazdy').add({
          eremizaId,
          tytul: alarm.rodzaj || 'Alarm',
          lokalizacja: alarm.miejsceZdarzenia || '',
          opis: alarm.opis || '',
          kategoria: (alarm.rodzaj && alarm.rodzaj.toLowerCase().includes('po|ar')) ? 'pozar' : (alarm.rodzaj && alarm.rodzaj.toLowerCase().includes('miejscowe')) ? 'miejscoweZagrozenie' : 'inne',
          dataWyjazdu: (dataAlarmu instanceof Date ? admin.firestore.Timestamp.fromDate(dataAlarmu) : admin.firestore.Timestamp.now()),
          status: 'aktywny',
          zrodlo: 'e-remiza',
          rodzaj: alarm.rodzaj,
          utworzonePrzez: 'system',
          czasTrwaniaGodziny: 0,
          liczbaStrazakow: 0,
          priorytet: 'normalny',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`pobierzAlarmy: dodano alarm ${docRef.id} - ${alarm.rodzaj} @ ${alarm.miejsceZdarzenia}`);
        importowanych++;

        // Sprawdz czy jest wyjazd z discorda w ciagu 5 minut do scalenia
        const piecMinMs = dataAlarmu.getTime() - 5 * 60 * 1000;
        const piecMinTs = admin.firestore.Timestamp.fromMillis(piecMinMs);
        const discordWyjazdySnap = await admin.firestore()
          .collection('wyjazdy')
          .where('godzinaAlarmu', '>=', piecMinTs)
          .get();
        const discordWyjazdy = discordWyjazdySnap.docs.filter(d => !d.data().eremizaId);

        if (discordWyjazdy.length > 0) {
          const discordDoc = discordWyjazdy[0];
          const godzinaAlarmu = discordDoc.data().godzinaAlarmu;
          await docRef.update({ godzinaAlarmu, eremizaAlarmWyslany: true });

          // Kopiuj odpowiedzi z wyjazdu Discord do e-Remiza
          const odpSnap = await discordDoc.ref.collection('odpowiedzi').get();
          for (const odpDoc of odpSnap.docs) {
            await docRef.collection('odpowiedzi').doc(odpDoc.id).set(odpDoc.data());
          }
          // Usun wyjazd z discorda
          await discordDoc.ref.delete();
          console.log('pobierzAlarmy: scalono wyjazd Discord ' + discordDoc.id + ' z e-Remiza ' + docRef.id);
        } else {
          // Brak wyjazdu z Discorda  czekaj 1 minute na sprawdzenie
          await docRef.update({ eremizaAlarmWyslany: false });
        }
      }

      console.log(`pobierzAlarmy: zaimportowano ${importowanych} nowych alarmow`);
      return null;
    } catch (e) {
      console.error('pobierzAlarmy: blad:', e.message);
      return null;
    }
  });

/**
 * Co minute sprawdza wyjazdy e-remiza czekajace na alarm FCM.
 * Jesli w ciagu 1 minuty Discord nie wyslal alarmu z 'Kolumna', wysyBa FCM alarm.
 */
exports.sprawdzAlarmyERemiza = functions
  .region('europe-central2')
  .pubsub.schedule('every 1 minutes')
  .onRun(async () => {
    try {
      const oczekujaceSnap = await admin.firestore()
        .collection('wyjazdy')
        .where('zrodlo', '==', 'e-remiza')
        .where('eremizaAlarmWyslany', '==', false)
        .get();

      if (oczekujaceSnap.empty) return null;

      const teraz = Date.now();
      for (const wyjazdDoc of oczekujaceSnap.docs) {
        const wyjazd = wyjazdDoc.data();
        const wyjazdId = wyjazdDoc.id;

        const createdAt = wyjazd.createdAt ? wyjazd.createdAt.toMillis() : teraz;
        const wiek = teraz - createdAt;

        // Czekaj co najmniej 1 minute od importu
        if (wiek < 60 * 1000) continue;

        // Jesli starszy niz 10 minut  nie wysylaj juz alarmu
        if (wiek > 10 * 60 * 1000) {
          await wyjazdDoc.ref.update({ eremizaAlarmWyslany: true });
          console.log('sprawdzAlarmyERemiza: przeoczono (>10min) ' + wyjazdId);
          continue;
        }

        const dataWyjazduMs = wyjazd.dataWyjazdu ? wyjazd.dataWyjazdu.toMillis() : createdAt;

        // Sprawdz czy Discord obsluzylo alarm (config/discord_monitor.lastAlarmAt)
        const discordStateDoc = await admin.firestore().doc('config/discord_monitor').get();
        const lastAlarmAt = discordStateDoc.exists ? discordStateDoc.data().lastAlarmAt : null;
        const lastAlarmMs = lastAlarmAt ? lastAlarmAt.toMillis() : 0;
        const roznicaDiscord = Math.abs(lastAlarmMs - dataWyjazduMs);

        if (lastAlarmMs > 0 && roznicaDiscord < 5 * 60 * 1000) {
          // Discord obsluzylo  sprawdz czy jest wyjazd do scalenia
          const piecMinTs = admin.firestore.Timestamp.fromMillis(dataWyjazduMs - 5 * 60 * 1000);
          const discordWyjazdySnap = await admin.firestore()
            .collection('wyjazdy')
            .where('godzinaAlarmu', '>=', piecMinTs)
            .get();
          const discordWyjazdy = discordWyjazdySnap.docs.filter(
            d => !d.data().eremizaId && d.id !== wyjazdId
          );

          if (discordWyjazdy.length > 0) {
            const discordDoc = discordWyjazdy[0];
            const godzinaAlarmu = discordDoc.data().godzinaAlarmu;
            await wyjazdDoc.ref.update({ godzinaAlarmu, eremizaAlarmWyslany: true });
            const odpSnap = await discordDoc.ref.collection('odpowiedzi').get();
            for (const odpDoc of odpSnap.docs) {
              await wyjazdDoc.ref.collection('odpowiedzi').doc(odpDoc.id).set(odpDoc.data());
            }
            await discordDoc.ref.delete();
            console.log('sprawdzAlarmyERemiza: scalono Discord ' + discordDoc.id + ' z e-Remiza ' + wyjazdId);
          } else {
            await wyjazdDoc.ref.update({ eremizaAlarmWyslany: true });
            console.log('sprawdzAlarmyERemiza: Discord obsluzylo, brak wyjazdu do scalenia ' + wyjazdId);
          }
          continue;
        }

        // Discord nie obsluzylo w ciagu 1 minuty  wyslij alarm FCM z e-Remiza
        const tokeny = await pobierzTokenyWszystkich();
        if (tokeny.length > 0) {
          const alarmBody = ((wyjazd.tytul || 'Alarm') + ' - ' + (wyjazd.lokalizacja || '')).trim();
          await admin.firestore().collection('notifications').add({
            type: 'ALARM',
            tokens: tokeny,
            wyjazdId,
            kategoria: wyjazd.rodzaj || wyjazd.tytul || 'Alarm',
            lokalizacja: wyjazd.lokalizacja || '',
            opis: wyjazd.opis || '',
            title: 'ALARM!',
            body: alarmBody,
            data: { type: 'ALARM', wyjazdId },
            utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
            wyslane: false,
          });
          console.log('sprawdzAlarmyERemiza: wyslano alarm FCM dla ' + wyjazdId);
        }
        await wyjazdDoc.ref.update({
          eremizaAlarmWyslany: true,
          godzinaAlarmu: admin.firestore.Timestamp.fromMillis(createdAt),
        });
      }
      return null;
    } catch (e) {
      console.error('sprawdzAlarmyERemiza: blad:', e.message);
      return null;
    }
  });

/**
 * Nowa wiadomosc w czacie grupowym -> powiadomienie FCM
 */
exports.nowaWiadomoscCzat = functions
  .region('europe-central2')
  .firestore.document('czat_grupowy/{msgId}')
  .onCreate(async (snap) => {
    const msg = snap.data();
    const nadawca = msg.uzytkownikImie || msg.nadawcaNazwisko || msg.nadawcaImie || msg.imieNazwisko || null;
    if (!nadawca) { console.log('nowaWiadomoscCzat: brak nazwy nadawcy, pomijam'); return null; }
    const tresc = msg.tresc || msg.tekst || '';
    const skrot = tresc.length > 80 ? tresc.substring(0, 80) + '...' : tresc;

    const strazacySnap = await admin.firestore()
      .collection('strazacy')
      .where('aktywny', '==', true)
      .get();
    const tokeny = [];
    strazacySnap.docs.forEach((doc) => {
      if (doc.id === msg.uzytkownikId) return;
      const token = doc.data().fcmToken;
      if (token) tokeny.push(token);
    });

    await wyslijFCMLive(
      'czat',
      'Czat: ' + nadawca,
      skrot,
      tokeny,
      { kategoria: 'czat', msgId: snap.id }
    );
    console.log('Powiadomienie czat wyslane (' + tokeny.length + ' odbiorcow)');
    return null;
  });

/**
 * Nowe wydarzenie w terminarzu -> powiadomienie FCM
 */
exports.noweWydarzenie = functions
  .region('europe-central2')
  .firestore.document('wydarzenia/{eventId}')
  .onCreate(async (snap) => {
    const ev = snap.data();
    const tytul = ev.tytul || ev.nazwa || 'Nowe wydarzenie';
    const typ = ev.typ || ev.typWydarzenia || '';
    const tokeny = await pobierzTokenyWszystkich();
    await wyslijFCMLive(
      'WYDARZENIE',
      (typ ? typ + ': ' : 'Wydarzenie: ') + tytul,
      ev.opis || ev.miejsce || 'Sprawdz szczegoly w aplikacji',
      tokeny,
      { wydarzenieId: snap.id, tytul, typWydarzenia: typ }
    );
    console.log('Powiadomienie nowe wydarzenie wyslane');
    return null;
  });

/**
 * Nowa kontrola pojazdu -> powiadomienie FCM
 */
exports.nowaKrolaPojazdu = functions
  .region('europe-central2')
  .firestore.document('kontrole_pojazdow/{kontrolaId}')
  .onCreate(async (snap) => {
    const k = snap.data();
    const woz = k.wozNazwa || k.pojazd || k.wozId || 'pojazd';
    const data = k.data
      ? new Date(k.data.toDate()).toLocaleDateString('pl-PL')
      : '';
    const tokeny = await pobierzTokenyWszystkich();
    await wyslijFCMLive(
      'PRZEGLAD',
      'Kontrola pojazdu: ' + woz,
      data ? 'Data: ' + data : 'Sprawdz szczegoly w aplikacji',
      tokeny,
      { kontrolaId: snap.id, woz }
    );
    console.log('Powiadomienie kontrola pojazdu wyslane');
    return null;
  });

/**
 * Nowy sprzet lub aktualizacja terminu przegladu sprzetu -> powiadomienie
 * Wywoływane gdy dodano nowy dokument do kolekcji 'sprzet'
 */
exports.nowySprzetLubPrzeglad = functions
  .region('europe-central2')
  .firestore.document('sprzet/{sprzetId}')
  .onCreate(async (snap) => {
    const s = snap.data();
    const nazwa = s.nazwa || 'sprzet';
    const kiedy = s.dataNastepnegoPrzegladu
      ? new Date(s.dataNastepnegoPrzegladu.toDate()).toLocaleDateString('pl-PL')
      : '';
    const tokeny = await pobierzTokenyWszystkich();
    await wyslijFCMLive(
      'PRZEGLAD',
      'Nowy sprzet: ' + nazwa,
      kiedy ? 'Przeglad: ' + kiedy : 'Dodano nowy sprzet do bazy',
      tokeny,
      { sprzetId: snap.id, nazwa }
    );
    console.log('Powiadomienie nowy sprzet wyslane');
    return null;
  });

/**
 * Nowe szkolenie/badanie/kurs -> powiadomienie do konkretnego strazaka
 * Jezeli dataWaznosci istnieje i <= 30 dni - informacja o krotkim terminie
 */
exports.noweSzkolenieLubBadanie = functions
  .region('europe-central2')
  .firestore.document('szkolenia/{szkId}')
  .onCreate(async (snap) => {
    const sz = snap.data();
    const nazwa = sz.nazwa || 'Nowe szkolenie/badanie';
    const typ = sz.typ || '';
    const strazakId = sz.strazakId;

    // Ustal termin waznosci
    let terminInfo = '';
    if (sz.dataWaznosci) {
      const data = new Date(sz.dataWaznosci.toDate());
      const dniDo = Math.ceil((data - Date.now()) / (1000 * 60 * 60 * 24));
      const dataStr = data.toLocaleDateString('pl-PL');
      if (dniDo < 0) {
        terminInfo = 'Wygaslo ' + dataStr;
      } else if (dniDo <= 30) {
        terminInfo = 'Wazne do ' + dataStr + ' (' + dniDo + ' dni)';
      } else {
        terminInfo = 'Wazne do ' + dataStr;
      }
    } else {
      terminInfo = 'Bezterminowe';
    }

    // Powiadom konkretnego strazaka (jesli przypisany) lub wszystkich
    let tokeny;
    let imieStrazaka = '';
    if (strazakId) {
      const sdoc = await admin.firestore().collection('strazacy').doc(strazakId).get();
      const sdata = sdoc.data();
      const token = sdata && sdata.fcmToken;
      tokeny = token ? [token] : [];
      imieStrazaka = sdata ? (sdata.imie || '') : '';
    } else {
      tokeny = await pobierzTokenyWszystkich();
    }

    const tytul = typ ? typ + ': ' + nazwa : nazwa;
    const body = imieStrazaka
      ? imieStrazaka + ' - ' + terminInfo
      : terminInfo || 'Sprawdz szczegoly w aplikacji';

    await wyslijFCMLive(
      'SZKOLENIE',
      tytul,
      body,
      tokeny,
      { szkId: snap.id, nazwa, typ, strazakId: strazakId || '' }
    );
    console.log('Powiadomienie szkolenie/badanie/kurs wyslane');
    return null;
  });

/**
 * Nowe ostrzezenie IMGW -> powiadomienie FCM do wszystkich
 */
exports.noweOstrzezenieIMGW = functions
  .region('europe-central2')
  .firestore.document('ostrzezenia_imgw/{ostId}')
  .onCreate(async (snap) => {
    const ost = snap.data();
    const zjawisko = ost.zjawisko || ost.typ || 'Ostrzezenie';
    const poziom = ost.poziom ? ' (stopien ' + ost.poziom + ')' : '';
    const tokeny = await pobierzTokenyWszystkich();
    await wyslijFCMLive(
      'IMGW',
      'IMGW: ' + zjawisko + poziom,
      ost.opis || ost.tresc || 'Sprawdz szczegoly w aplikacji',
      tokeny,
      { id: snap.id, tytul: zjawisko, poziom: String(ost.poziom || ''), typ: zjawisko }
    );
    console.log('Powiadomienie IMGW wyslane');
    return null;
  });

/**
 * Nowe ostrzezenie RCB -> powiadomienie FCM do wszystkich
 */
exports.noweOstrzezenieRCB = functions
  .region('europe-central2')
  .firestore.document('ostrzezenia_rcb/{ostId}')
  .onCreate(async (snap) => {
    const ost = snap.data();
    const tytul = ost.tytul || ost.typ || 'Alert RCB';
    const tokeny = await pobierzTokenyWszystkich();
    await wyslijFCMLive(
      'IMGW',
      'Alert RCB: ' + tytul,
      ost.tresc || ost.opis || 'Sprawdz szczegoly w aplikacji',
      tokeny,
      { id: snap.id, tytul, typ: 'RCB' }
    );
    console.log('Powiadomienie RCB wyslane');
    return null;
  });

exports.nowaReakcjaAlarm = functions
  .region('europe-central2')
  .firestore.document('wyjazdy/{wyjazdId}/odpowiedzi/{strazakId}')
  .onCreate(async (snap, context) => {
    const { wyjazdId, strazakId } = context.params;
    const odpowiedz = snap.data();
    const status = odpowiedz.status || 'nieznany';

    // Pobierz dane strażaka
    let imie = 'Strażak';
    try {
      const strazakDoc = await admin.firestore().collection('strazacy').doc(strazakId).get();
      if (strazakDoc.exists) {
        const s = strazakDoc.data();
        imie = s.imie || s.displayName || 'Strażak';
      }
    } catch (e) {
      console.error('Blad pobierania strazaka:', e);
    }

    // Pobierz dane wyjazdu
    let wyjazdInfo = '';
    try {
      const wyjazdDoc = await admin.firestore().collection('wyjazdy').doc(wyjazdId).get();
      if (wyjazdDoc.exists) {
        const w = wyjazdDoc.data();
        wyjazdInfo = w.lokalizacja || w.kategoria || '';
      }
    } catch (e) {
      console.error('Blad pobierania wyjazdu:', e);
    }

    // Emoji dla statusu
    const statusEmoji = status === 'jadę' ? '✅' : status === 'wrzuć ciuchy' ? '👕' : '❌';

    const body = wyjazdInfo
      ? `${statusEmoji} ${status} — ${wyjazdInfo}`
      : `${statusEmoji} ${status}`;

    // Powiadom wszystkich oprócz osoby która odpowiedziała
    const wszystkieTokeny = await pobierzTokenyWszystkich();
    // Pobierz token reagującego żeby go wykluczyć
    let tokenReagujacego = null;
    try {
      const strazakDoc2 = await admin.firestore().collection('strazacy').doc(strazakId).get();
      if (strazakDoc2.exists) tokenReagujacego = strazakDoc2.data().fcmToken || null;
    } catch (e) { /* ignoruj */ }
    const tokeny = wszystkieTokeny.filter(t => t !== tokenReagujacego);
    if (tokeny.length === 0) return null;

    await wyslijFCMLive(
      'REAKCJA_ALARM',
      `${imie}: ${status}`,
      body,
      tokeny,
      { wyjazdId, strazakId, status }
    );
    console.log(`Reakcja ${imie} (${status}) na wyjazd ${wyjazdId} wyslana do ${tokeny.length} osob`);
    return null;
  });

exports.dotarcieDoremizy = functions
  .region('europe-central2')
  .firestore.document('wyjazdy/{wyjazdId}/odpowiedzi/{strazakId}')
  .onUpdate(async (change, context) => {
    const { wyjazdId, strazakId } = context.params;
    const przed = change.before.data();
    const po = change.after.data();

    // Reaguj tylko gdy pojawia się czasDotarcia (wcześniej go nie było)
    if (przed.czasDotarcia || !po.czasDotarcia) return null;

    // Pobierz dane strażaka
    let imie = 'Strażak';
    try {
      const strazakDoc = await admin.firestore().collection('strazacy').doc(strazakId).get();
      if (strazakDoc.exists) {
        const s = strazakDoc.data();
        imie = s.imie || s.displayName || 'Strażak';
      }
    } catch (e) {
      console.error('Blad pobierania strazaka:', e);
    }

    // Pobierz lokalizację wyjazdu
    let wyjazdInfo = '';
    try {
      const wyjazdDoc = await admin.firestore().collection('wyjazdy').doc(wyjazdId).get();
      if (wyjazdDoc.exists) {
        wyjazdInfo = wyjazdDoc.data().lokalizacja || '';
      }
    } catch (e) { /* ignoruj */ }

    // Powiadom wszystkich oprócz tego strażaka
    const wszystkieTokeny = await pobierzTokenyWszystkich();
    let tokenSelf = null;
    try {
      const selfDoc = await admin.firestore().collection('strazacy').doc(strazakId).get();
      if (selfDoc.exists) tokenSelf = selfDoc.data().fcmToken || null;
    } catch (e) { /* ignoruj */ }
    const tokeny = wszystkieTokeny.filter(t => t !== tokenSelf);
    if (tokeny.length === 0) return null;

    const body = '🏠 Dotarł na remizę';

    await wyslijFCMLive(
      'ALARM',
      `${imie} dotarł na remizę`,
      body,
      tokeny,
      { wyjazdId, strazakId, typ: 'DOTARCIE_REMIZA' }
    );
    console.log(`Dotarcie ${imie} na remize wyslane do ${tokeny.length} osob`);
    return null;
  });


/**
 * Co minute sprawdza nowe wiadomosci na Discordzie i wysyla powiadomienia FCM.
 * Zastepuje Render worker (ktory zasypial jako free-tier worker).
 */
exports.sprawdzDiscordMessages = functions
  .region('europe-central2')
  .pubsub.schedule('every 1 minutes')
  .onRun(async () => {
    try {
      const cfgDoc = await admin.firestore().doc('config/discord_worker').get();
      if (!cfgDoc.exists || !cfgDoc.data().token) {
        console.log('sprawdzDiscordMessages: brak konfiguracji w config/discord_worker');
        return null;
      }
      const cfg = cfgDoc.data();
      const discordToken = cfg.token || '';
      const channelId = cfg.channel_id || '1193142209470533733';
      const alarmKeyword = (cfg.alarm_keyword || 'kolumna').toLowerCase();
      const cooldownMin = Number(cfg.cooldown_min || 4);

      const stateRef = admin.firestore().doc('config/discord_monitor');
      const stateSnap = await stateRef.get();
      const stateData = stateSnap.exists ? stateSnap.data() : {};
      let lastMessageId = stateData.lastMessageId || null;
      const lastAlarmAt = stateData.lastAlarmAt ? stateData.lastAlarmAt.toDate() : null;

      const url = 'https://discord.com/api/v10/channels/' + channelId + '/messages?limit=10';
      const resp = await fetch(url, {
        headers: { Authorization: 'Bot ' + discordToken, 'Content-Type': 'application/json' },
      });

      if (resp.status === 429) {
        console.warn('sprawdzDiscordMessages: rate limit Discord');
        return null;
      }
      if (!resp.ok) {
        console.warn('sprawdzDiscordMessages: Discord API error', resp.status);
        return null;
      }

      const messages = await resp.json();
      if (!Array.isArray(messages) || messages.length === 0) return null;

      const newest = messages[0];
      const newestId = String(newest.id || '');
      if (!newestId) return null;

      if (!lastMessageId) {
        await stateRef.set({ lastMessageId: newestId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        console.log('sprawdzDiscordMessages: pierwsze uruchomienie, zapisano lastMessageId');
        return null;
      }

      if (newestId === lastMessageId) return null;

      const freshMessages = [];
      for (const msg of messages) {
        if (String(msg.id) === lastMessageId) break;
        freshMessages.push(msg);
      }

      if (freshMessages.length === 0) {
        await stateRef.set({ lastMessageId: newestId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return null;
      }

      const tokeny = await pobierzTokenyWszystkich();
      if (tokeny.length === 0) {
        console.warn('sprawdzDiscordMessages: brak tokenow FCM');
        await stateRef.set({ lastMessageId: newestId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return null;
      }

      for (const msg of freshMessages.reverse()) {
        const content = (msg.content || '').toString();
        const embeds = Array.isArray(msg.embeds) ? msg.embeds : [];
        let title = 'Nowa wiadomosc Discord';
        let body = content || '(Zalacznik)';
        if (embeds.length > 0 && embeds[0].title) {
          title = embeds[0].title;
          body = embeds[0].description || content;
        }
        const authorName = (msg.author && msg.author.username) ? msg.author.username : 'Discord';

        const fullText = (title + ' ' + body + ' ' + content).toLowerCase();
        const isAlarm = fullText.includes(alarmKeyword);

        let wyjazdId = '';
        if (isAlarm) {
          const teraz = Date.now();
          const cooldownOk = !lastAlarmAt || (teraz - lastAlarmAt.getTime() >= cooldownMin * 60 * 1000);
          if (cooldownOk) {
            const since = new Date(teraz - 10 * 60 * 1000);
            const recentSnap = await admin.firestore().collection('wyjazdy')
              .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(since))
              .limit(5).get();
            if (!recentSnap.empty) {
              wyjazdId = recentSnap.docs[0].id;
            } else {
              const wyjazdRef = admin.firestore().collection('wyjazdy').doc();
              wyjazdId = wyjazdRef.id;
              await wyjazdRef.set({
                tytul: 'Alarm - Kolumna',
                lokalizacja: '',
                opis: (title + ' ' + content).substring(0, 300),
                kategoria: 'miejscoweZagrozenie',
                status: 'aktywny',
                zrodlo: 'discord',
                godzinaAlarmu: admin.firestore.FieldValue.serverTimestamp(),
                dataWyjazdu: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                utworzonePrzez: 'system_discord_cf',
                strazacyIds: [],
              });
            }
            await stateRef.set({ lastAlarmAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
            console.log('sprawdzDiscordMessages: ALARM wykryty, wyjazdId=' + wyjazdId);
          }
        }

        await admin.firestore().collection('powiadomienia').add({
          tokens: tokeny,
          title: isAlarm ? 'ALARM - Kolumna' : ('Discord: ' + authorName),
          body: (body || content).substring(0, 200),
          data: {
            type: isAlarm ? 'ALARM' : 'discord',
            wyjazdId: wyjazdId,
            messageId: String(msg.id || ''),
            author: authorName,
            channelId: channelId,
            fullContent: String(content || ''),
            fullTitle: String(title || ''),
            fullBody: String(body || ''),
          },
          utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
          wyslane: false,
        });
        console.log('sprawdzDiscordMessages: zakolejkowano powiadomienie dla ' + tokeny.length + ' tokenow');
      }

      await stateRef.set({ lastMessageId: newestId, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      return null;
    } catch (e) {
      console.error('sprawdzDiscordMessages: blad:', e.message);
      return null;
    }
  });