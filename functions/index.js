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
      console.log('Brak szkoleń wygasających w ciągu 30 dni');
      return null;
    }

    const szkolenia = szkoleniaSnapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((s) => !s.powiadomionoEmail30d);

    if (szkolenia.length === 0) {
      console.log('Wszystkie szkolenia zostały już oznaczone jako powiadomione');
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
      console.log('Brak adresów email administratorów lub moderatorów');
      return null;
    }

    const linie = szkolenia.map((s) => {
      const strazak = strazakMap.get(s.strazakId) || 'Nieznany strażak';
      const dataWaznosci = s.dataWaznosci?.toDate ? s.dataWaznosci.toDate() : null;
      const dataText = dataWaznosci
        ? dataWaznosci.toISOString().slice(0, 10)
        : 'brak daty';
      return `- ${strazak} | ${s.nazwa || 'Szkolenie'} | ważne do ${dataText}`;
    }).join('\n');

    const smtp = functions.config().smtp || {};
    const fromAddress = smtp.from || smtp.user;

    await transport.sendMail({
      from: fromAddress,
      to: fromAddress,
      bcc: adresy,
      subject: 'Przypomnienie: szkolenia wygasają w ciągu 30 dni',
      text: `Szkolenia do odnowienia w ciągu 30 dni:\n\n${linie}`,
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

    console.log(`Wysłano przypomnienia email: ${adresy.length} adresów, ${szkolenia.length} szkoleń`);
    return null;
  });

/**
 * Cloud Function do wysyłania powiadomień push
 * Nasłuchuje na nowe dokumenty w kolekcji 'notifications'
 */
exports.wyslijPowiadomienie = functions
  .region('europe-central2')
  .firestore.document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    // Jeśli już wysłane, pomiń
    if (notification.wyslane) {
      return null;
    }

    const tokens = notification.tokens || [];
    if (tokens.length === 0) {
      console.log('Brak tokenów FCM');
      return null;
    }

    let message;

    // Przygotuj wiadomość w zależności od typu
    if (notification.type === 'ALARM') {
      // Dla ALARMU wysyłamy zarówno payload "notification" (żeby system
      // Android sam pokazał głośne powiadomienie nawet, gdy aplikacja
      // jest ubita/zablokowana), jak i payload "data" do obsługi
      // po stronie klienta.
      const alarmTitle = '🚨 ALARM!';
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
            channelId: 'alarm_channel',
            sound: 'syrena',
            priority: 'PRIORITY_MAX',
          },
        },
      };
    } else if (notification.type === 'WYDARZENIE') {
      const data = notification.dataRozpoczecia?.toDate() || new Date();
      message = {
        notification: {
          title: `📅 Nowe wydarzenie: ${notification.typWydarzenia}`,
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
      const data = notification.dataRozpoczecia?.toDate() || new Date();
      message = {
        notification: {
          title: '⏰ Przypomnienie',
          body: `Jutro: ${notification.tytul}`,
        },
        data: {
          type: 'PRZYPOMNIENIE',
          wydarzenieId: notification.wydarzenieId || '',
          tytul: notification.tytul || '',
        },
      };
    } else if (notification.type === 'IMGW') {
      message = {
        notification: {
          title: notification.title || '⚠️ Ostrzeżenie IMGW',
          body: notification.body || 'Nowe ostrzeżenie IMGW',
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
          title: notification.title || '💬 Discord',
          body: notification.body || 'Nowa wiadomość na Discord',
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
    } else {
      console.log('Nieznany typ powiadomienia:', notification.type);
      return null;
    }

    // Wyślij powiadomienia (do 500 tokenów naraz)
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
        
        console.log(`Wysłano: ${response.successCount}, Błędy: ${response.failureCount}`);
      } catch (error) {
        console.error('Błąd wysyłania powiadomień:', error);
        failureCount += batch.length;
      }
    }

    // Oznacz jako wysłane
    await snap.ref.update({
      wyslane: true,
      wyslaneDnia: admin.firestore.FieldValue.serverTimestamp(),
      successCount,
      failureCount,
    });

    console.log(`✅ Powiadomienia wysłane: ${successCount} sukces, ${failureCount} błędów`);
    return null;
  });

/**
 * Webhook do synchronizacji alarmów z eRemiza
 * 
 * URL: https://europe-central2-[PROJEKT_ID].cloudfunctions.net/synchronizujAlarmZeRemiza
 * 
 * Przykład requestu z eRemiza:
 * POST /synchronizujAlarmZeRemiza
 * Content-Type: application/json
 * Authorization: Bearer OSP_KOLUMNA_SECRET_2026
 * 
 * Body:
 * {
 *   "id": "ER-2026-001234",
 *   "tytul": "Pożar budynku mieszkalnego",
 *   "opis": "Dym z okna na pierwszym piętrze",
 *   "adres": "ul. Główna 15, Kolumna",
 *   "typ": "pozar",
 *   "data": "2026-01-28T14:30:00Z",
 *   "priorytet": "wysoki"
 * }
 */
exports.synchronizujAlarmZeRemiza = functions
  .region('europe-central2')
  .https.onRequest(async (req, res) => {
    
    // CORS dla testów (opcjonalne)
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }
    
    // Sprawdź metodę
    if (req.method !== 'POST') {
      return res.status(405).json({ 
        success: false, 
        error: 'Tylko metoda POST' 
      });
    }
    
    // Sprawdź autoryzację
    const authHeader = req.headers['authorization'];
    const expectedToken = 'Bearer OSP_KOLUMNA_SECRET_2026'; // ZMIEŃ na własny tajny klucz!
    
    if (authHeader !== expectedToken) {
      console.warn('Nieautoryzowany dostęp:', authHeader);
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
          error: 'Brak tytułu alarmu' 
        });
      }
      
      // Mapowanie kategorii z eRemiza na kategorie w aplikacji
      const mapujKategorie = (typZeRemiza) => {
        const mapping = {
          'pozar': 'pozar',
          'pożar': 'pozar',
          'wypadek': 'wypadek',
          'wypadek_drogowy': 'wypadek',
          'miejscowe': 'miejscowe',
          'miejscowe_zagrozenie': 'miejscowe',
          'false_alarm': 'falszywy',
          'falszywy_alarm': 'falszywy',
          'cwiczenia': 'cwiczenia',
          'ćwiczenia': 'cwiczenia',
        };
        
        const typ = (typZeRemiza || '').toLowerCase();
        return mapping[typ] || 'inne';
      };
      
      // Sprawdź czy już nie istnieje (zapobieganie duplikatom)
      if (alarm.id) {
        const existing = await admin.firestore()
          .collection('wyjazdy')
          .where('eRemizaId', '==', alarm.id)
          .limit(1)
          .get();
        
        if (!existing.empty) {
          console.log('Wyjazd już istnieje:', alarm.id);
          return res.status(200).json({ 
            success: true, 
            duplicate: true,
            wyjazdId: existing.docs[0].id,
            message: 'Wyjazd już istnieje w bazie' 
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
      
      console.log(`✅ Dodano wyjazd ${wyjazdRef.id} z eRemiza (ID: ${alarm.id})`);
      
      // Opcjonalnie: Wyślij powiadomienie (jeśli chcesz)
      // await wyslijPowiadomienie(wyjazdRef.id, wyjazdData);
      
      return res.status(200).json({ 
        success: true, 
        wyjazdId: wyjazdRef.id,
        message: 'Wyjazd pomyślnie dodany',
        data: {
          tytul: wyjazdData.tytul,
          kategoria: wyjazdData.kategoria,
          lokalizacja: wyjazdData.lokalizacja
        }
      });
      
    } catch (error) {
      console.error('❌ Błąd synchronizacji z eRemiza:', error);
      return res.status(500).json({ 
        success: false, 
        error: error.message,
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });
    }
});

/**
 * Webhook do aktualizacji istniejących wyjazdów z eRemiza
 * 
 * URL: https://europe-central2-[PROJEKT_ID].cloudfunctions.net/aktualizujWyjazdZeRemiza
 * 
 * Przykład requestu:
 * POST /aktualizujWyjazdZeRemiza
 * Content-Type: application/json
 * Authorization: Bearer OSP_KOLUMNA_SECRET_2026
 * 
 * Body:
 * {
 *   "id": "ER-2026-001234",
 *   "status": "zakończony",
 *   "czasTrwania": 2.5,
 *   "liczbaStrazakow": 12,
 *   "uwagi": "Akcja zakończona sukcesem"
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
      
      // Znajdź wyjazd po eRemizaId
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
        updateData.status = update.status === 'zakończony' || update.status === 'zakonczone' 
          ? 'zakończony' 
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
      
      // Wykonaj aktualizację
      await admin.firestore()
        .collection('wyjazdy')
        .doc(docId)
        .update(updateData);
      
      console.log(`✅ Zaktualizowano wyjazd ${docId} (eRemiza ID: ${update.id})`);
      
      return res.status(200).json({ 
        success: true, 
        wyjazdId: docId,
        message: 'Wyjazd zaktualizowany',
        updated: updateData
      });
      
    } catch (error) {
      console.error('❌ Błąd aktualizacji wyjazdu:', error);
      return res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
});

/**
 * Funkcja testowa - usuń w produkcji!
 * Pozwala sprawdzić czy Cloud Functions działają
 */
exports.testConnection = functions
  .region('europe-central2')
  .https.onRequest((req, res) => {
    res.json({ 
      success: true, 
      message: 'OSP Kolumna Cloud Functions działają!',
      timestamp: new Date().toISOString(),
      region: 'europe-central2'
    });
  });

/**
 * ========================================================================
 * NOWA FUNKCJA: Automatyczna synchronizacja z eRemiza API
 * ========================================================================
 * Odpytuje e-Remizę co 5 minut i pobiera nowe alarmy
 * Wymaga konfiguracji zmiennych środowiskowych:
 * - EREMIZA_EMAIL: email do logowania w e-Remiza
 * - EREMIZA_PASSWORD: hasło do logowania w e-Remiza
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
  
  // eRemiza używa prostego JWT bez podpisu (insecure, ale tak działa ich API)
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
 * P → pożar
 * Alarm (MZ) → miejscowe zagrożenie
 * Ć → ćwiczenia
 * PNZR → zabezpieczenie (rejonu JRG Łask)
 */
function mapEremizaCategory(subKind) {
  if (!subKind) return 'inne';
  
  const subKindUpper = subKind.toUpperCase().trim();
  
  // Dokładne mapowanie według specyfikacji
  if (subKindUpper === 'P') return 'pozar';
  if (subKindUpper === 'ALARM (MZ)' || subKindUpper === 'MZ') return 'miejscowe';
  if (subKindUpper === 'Ć' || subKindUpper === 'C') return 'cwiczenia';
  if (subKindUpper === 'PNZR') return 'zabezpieczenie';
  
  // Fallback - częściowe dopasowanie
  if (subKindUpper.includes('POŻAR') || subKindUpper.includes('POZAR')) return 'pozar';
  if (subKindUpper.includes('WYPADEK')) return 'wypadek';
  if (subKindUpper.includes('MIEJSCOWE')) return 'miejscowe';
  if (subKindUpper.includes('ĆWICZENIA') || subKindUpper.includes('CWICZENIA')) return 'cwiczenia';
  if (subKindUpper.includes('ZABEZPIECZENIE')) return 'zabezpieczenie';
  if (subKindUpper.includes('FAŁSZYWY') || subKindUpper.includes('FALSZYWY')) return 'falszywy';
  
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
 * Firebase Blaze Plan wymagany (0.10 USD za milion wywołań)
 */
exports.syncEremizaAlarms = functions
  .region('europe-central2')
  .pubsub.schedule('every 5 minutes')
  .timeZone('Europe/Warsaw')
  .onRun(async (context) => {
    console.log('🔄 Rozpoczynam synchronizację z eRemiza...');

    try {
      // Pobierz dane logowania z Firebase Config
      const email = functions.config().eremiza?.email;
      const password = functions.config().eremiza?.password;

      if (!email || !password) {
        console.error('❌ Brak konfiguracji EREMIZA_EMAIL i EREMIZA_PASSWORD');
        console.error('Ustaw zmienne: firebase functions:config:set eremiza.email="..." eremiza.password="..."');
        return null;
      }

      // Połącz z API eRemiza
      const client = new EremizaClient(email, password);
      await client.login();
      console.log(`✅ Zalogowano jako: ${client.user.name || email}`);

      // Pobierz ostatnie 20 alarmów
      const alarms = await client.getAlarms(20, 0);
      console.log(`📥 Pobrano ${alarms.length} alarmów z eRemiza`);

      let addedCount = 0;
      let skippedCount = 0;

      // Przetwarzaj każdy alarm
      for (const alarm of alarms) {
        // FILTR: Pomijamy alarmy NIE z SK KP
        if (!isSKKPAlarm(alarm.bsisName)) {
          console.log(`⏭️ Pomijam alarm spoza SK KP: ${alarm.bsisName || 'brak nazwy'} (ID: ${alarm.id})`);
          skippedCount++;
          continue;
        }

        // Sprawdź czy alarm już istnieje (po ID z eRemiza)
        const existingQuery = await admin.firestore()
          .collection('wyjazdy')
          .where('eRemizaId', '==', alarm.id)
          .limit(1)
          .get();

        if (!existingQuery.empty) {
          console.log(`⏭️ Pomijam duplikat: ${alarm.id}`);
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

        // Dodaj współrzędne GPS jeśli dostępne
        if (alarm.latitude && alarm.longitude) {
          wyjazdData.wspolrzedne = {
            lat: alarm.latitude,
            lng: alarm.longitude
          };
        }

        // Zapisz do Firestore
        await admin.firestore().collection('wyjazdy').add(wyjazdData);
        addedCount++;
        
        console.log(`✅ Dodano alarm: ${alarm.id} - ${alarm.description?.substring(0, 50) || 'Brak opisu'}`);
      }

      console.log(`📊 Synchronizacja zakończona: ${addedCount} dodano, ${skippedCount} pominięto`);
      return { success: true, added: addedCount, skipped: skippedCount };

    } catch (error) {
      console.error('❌ Błąd synchronizacji z eRemiza:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Funkcja HTTP do ręcznego uruchomienia synchronizacji (do testów)
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

    console.log('🔄 Ręczna synchronizacja z eRemiza - rozpoczęta przez HTTP');

    try {
      const email = functions.config().eremiza?.email;
      const password = functions.config().eremiza?.password;

      if (!email || !password) {
        return res.status(500).json({
          success: false,
          error: 'Brak konfiguracji eRemiza. Użyj: firebase functions:config:set eremiza.email="..." eremiza.password="..."'
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
        message: `Synchronizacja zakończona: ${addedCount} dodano, ${skippedCount} pominięto`,
        added: addedCount,
        skipped: skippedCount,
        total: alarms.length
      });

    } catch (error) {
      console.error('❌ Błąd:', error);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

/**
 * Cron job wysyłający przypomnienia o wydarzeniach (uruchamiany codziennie)
 * Wysyła przypomnienia 1 dzień przed wydarzeniem o godz. 18:00
 */
exports.wyslijPrzypomnienia = functions
  .region('europe-central2')
  .pubsub.schedule('0 18 * * *') // Codziennie o 18:00
  .timeZone('Europe/Warsaw')
  .onRun(async (context) => {
    console.log('Sprawdzanie nadchodzących wydarzeń...');

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

      console.log(`Znaleziono ${wydarzeniaSnapshot.size} wydarzeń na jutro`);

      for (const doc of wydarzeniaSnapshot.docs) {
        const wydarzenie = doc.data();
        
        // Pobierz tokeny wszystkich aktywnych strażaków
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

      console.log('✅ Przypomnienia dodane do kolejki');
      return null;
    } catch (error) {
      console.error('Błąd wysyłania przypomnień:', error);
      return null;
    }
  });

/**
 * Cloud Function do wysyłania powiadomień Discord
 * Nasłuchuje na nowe dokumenty w kolekcji 'powiadomienia'
 */
exports.wyslijPowiadomienieDiscord = functions
  .region('europe-central2')
  .firestore.document('powiadomienia/{powiadomienieId}')
  .onCreate(async (snap, context) => {
    const powiadomienie = snap.data();
    
    // Jeśli już wysłane, pomiń
    if (powiadomienie.wyslane) {
      console.log('Powiadomienie już wysłane, pomijam');
      return null;
    }

    const tokens = powiadomienie.tokens || [];
    if (tokens.length === 0) {
      console.log('Brak tokenów FCM');
      await snap.ref.update({ wyslane: true });
      return null;
    }

    const type = powiadomienie.data?.type || 'discord';
    
    // FCM ma limit 256 znaków dla notification.body - skróć jeśli potrzeba
    const maxBodyLength = 200; // Zostaw zapas
    let bodyText = powiadomienie.body || 'Nowa wiadomość';
    if (bodyText.length > maxBodyLength) {
      bodyText = bodyText.substring(0, maxBodyLength - 3) + '...';
    }
    
    // Przygotuj wiadomość FCM
    const message = {
      notification: {
        title: powiadomienie.title || '💬 Discord',
        body: bodyText,
      },
      data: {
        type: type,
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
          sound: 'default',
          channelId: 'discord_channel',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Wyślij powiadomienia w batch'ach (do 500 tokenów naraz)
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

        // Usuń nieprawidłowe tokeny
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

          // Usuń nieprawidłowe tokeny z bazy
          for (const token of tokensToRemove) {
            const userSnapshot = await admin.firestore()
              .collection('strazacy')
              .where('fcmToken', '==', token)
              .get();
            
            for (const doc of userSnapshot.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
            }
          }
          
          console.log(`Usunięto ${tokensToRemove.length} nieprawidłowych tokenów`);
        }
      } catch (error) {
        console.error(`Błąd wysyłania batch ${i / batchSize + 1}:`, error);
        failureCount += batch.length;
      }
    }

    console.log(`✅ Wysłano powiadomienia Discord: ${successCount} sukces, ${failureCount} błąd`);

    // Oznacz jako wysłane
    await snap.ref.update({ 
      wyslane: true,
      successCount: successCount,
      failureCount: failureCount,
      wyslanoO: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });
