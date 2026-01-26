// Serwis Firebase do obsługi autentykacji
class SerwisFirebaseAutentykacja {
  constructor() {
    this.zalogowanyUżytkownik = null;
  }

  /**
   * Rejestruje nowego użytkownika
   * @param {string} email - Email użytkownika
   * @param {string} hasło - Hasło
   * @param {string} imię - Imię i nazwisko
   * @returns {Promise<{sukces: boolean, komunikat: string}>}
   */
  async zarejestruj(email, hasło, imię) {
    try {
      const wynik = await autentykacjaFirebase.createUserWithEmailAndPassword(email, hasło);

      // Zapisz dodatkowe dane użytkownika w Firestore
      await bazaDanychwFirestore.collection('użytkownicy').doc(wynik.user.uid).set({
        uid: wynik.user.uid,
        email: email,
        imię: imię,
        dataRejestracji: new Date(),
        status: 'aktywny',
        rola: 'strażak'
      });

      this.zalogowanyUżytkownik = wynik.user;
      console.log('✓ Użytkownik zarejestrowany:', email);
      return { sukces: true, komunikat: 'Rejestracja pomyślna' };
    } catch (błąd) {
      console.error('❌ Błąd rejestracji:', błąd.message);
      return { sukces: false, komunikat: this.mapujBładFirebase(błąd.code) };
    }
  }

  /**
   * Loguje użytkownika
   * @param {string} email - Email
   * @param {string} hasło - Hasło
   * @returns {Promise<{sukces: boolean, komunikat: string}>}
   */
  async zaloguj(email, hasło) {
    try {
      const wynik = await autentykacjaFirebase.signInWithEmailAndPassword(email, hasło);
      this.zalogowanyUżytkownik = wynik.user;

      // Pobierz dane użytkownika z Firestore
      const dokumentUżytkownika = await bazaDanychwFirestore
        .collection('użytkownicy')
        .doc(wynik.user.uid)
        .get();

      if (dokumentUżytkownika.exists) {
        localStorage.setItem('danęUżytkownika', JSON.stringify(dokumentUżytkownika.data()));
      }

      console.log('✓ Logowanie pomyślne:', email);
      return { sukces: true, komunikat: 'Logowanie pomyślne' };
    } catch (błąd) {
      console.error('❌ Błąd logowania:', błąd.message);
      return { sukces: false, komunikat: this.mapujBładFirebase(błąd.code) };
    }
  }

  /**
   * Wylogowuje użytkownika
   * @returns {Promise<void>}
   */
  async wyloguj() {
    try {
      await autentykacjaFirebase.signOut();
      this.zalogowanyUżytkownik = null;
      localStorage.removeItem('danęUżytkownika');
      console.log('✓ Wylogowanie pomyślne');
    } catch (błąd) {
      console.error('❌ Błąd wylogowania:', błąd.message);
    }
  }

  /**
   * Sprawdza czy użytkownik jest zalogowany
   * @returns {boolean}
   */
  czyZalogowany() {
    return this.zalogowanyUżytkownik !== null;
  }

  /**
   * Pobiera aktualnie zalogowanego użytkownika
   * @returns {firebase.User|null}
   */
  pobierzZalogowanegoUżytkownika() {
    return this.zalogowanyUżytkownik;
  }

  /**
   * Resetuje hasło dla danego email'a
   * @param {string} email - Email użytkownika
   * @returns {Promise<{sukces: boolean, komunikat: string}>}
   */
  async resetujHasło(email) {
    try {
      await autentykacjaFirebase.sendPasswordResetEmail(email);
      return { sukces: true, komunikat: 'Link do resetowania hasła wysłany na email' };
    } catch (błąd) {
      return { sukces: false, komunikat: this.mapujBładFirebase(błąd.code) };
    }
  }

  /**
   * Mapuje błędy Firebase na polskie komunikaty
   * @param {string} kodBłędu - Kod błędu Firebase
   * @returns {string} Polski komunikat o błędzie
   */
  mapujBładFirebase(kodBłędu) {
    const mapowanie = {
      'auth/email-already-in-use': 'Ten email jest już zarejestrowany',
      'auth/invalid-email': 'Nieprawidłowy format email',
      'auth/weak-password': 'Hasło jest za słabe (min. 6 znaków)',
      'auth/user-not-found': 'Użytkownik nie znaleziony',
      'auth/wrong-password': 'Nieprawidłowe hasło',
      'auth/too-many-requests': 'Za wiele prób logowania. Spróbuj później.',
      'auth/network-request-failed': 'Błąd połączenia sieciowego'
    };

    return mapowanie[kodBłędu] || 'Nieznany błąd. Spróbuj ponownie.';
  }
}

// Eksport dla użytku w aplikacji
const serwisFirebase = new SerwisFirebaseAutentykacja();
